from datetime import datetime

from batch.batcher import create_from_jobs

from core.models import (
    DID_ACCEPT_REQUEST,
    DELIVERY_TYPE_API
)

from core.models import (
    Courier,
    Job,
    SubNote,
    Catalog,
    Product,
    Contact,
    ContactAddress,
    ORDER_ORDERED
)
from core.util.markets import get_zone
from core.util.orders import (
    assign_pickup_info,
    generate_order_number
)
from core.util.products import (
    create_order
)

from core.util.tests import (
    generate_customer,
    generate_place,
    generate_job,
    generate_orderdata,
    simulate_delivery,
    add_product_to_orderdata)

from place.models import Place, OrderChannel, PlacePricing
from pm_base.util.geo import Point
from pm_user.models import User

from courier_push_notification.courier_events import (
    push_accepted_to_cleaner,
    push_auto_assigned_batch
)


################ BEGIN DB SPECIFIC DATA ###############

CATALOG = Catalog.objects.get(id=20)

CHICKEN_SAUSAGE = Product.objects.get(
    uuid='23dc46d8-2d6e-4859-af53-ffc4d1b8eb4a')
BEIGNET = Product.objects.get(uuid='6774de20-a0aa-41a3-8b18-49efe25178da')

################ END DB SPECIFIC DATA ###############


def get_cot_place():
    place = Place.objects.filter(name='COT_PLACE').first()
    if place:
        return place

    place = generate_place(
        name='COT_PLACE', default_channel=OrderChannel.IN_STORE)

    place.update(catalog=CATALOG)

    return place


def get_order_place():
    place = Place.objects.filter(name='ORDER_PLACE').first()
    if place:
        return place

    place = generate_place(
        name='ORDER_PLACE', default_channel=OrderChannel.PHONE)

    place.update(catalog=CATALOG)

    return place


def get_no_swipe_place():
    place = Place.objects.filter(name='NO_SWIPE_PLACE').first()
    if place:
        return place

    place = generate_place(
        name='NO_SWIPE_PLACE', default_channel=OrderChannel.PHONE)

    place.update(catalog=CATALOG)
    PlacePricing.objects.create(
        place=place, swipe_card=False, price_authority=True)
    return place


def generate_orderdata_from_spec(spec):
    orderdata = generate_orderdata(custom_order=spec['custom_order'])

    for item in spec['items']:
        product = item['product']
        options = []

        for group_name, option_names in item.get('option_groups', []):
            group = product.option_groups.get(name=group_name)
            options.extend(list(group.options.filter(name__in=option_names)))

        add_product_to_orderdata(
            orderdata,
            product,
            options=options,
            quantity=item.get('quantity'),
            special_instructions=item.get('special_instructions'))

    return orderdata


def generate_sub_notes(order_item, notes):
    for note in notes:
        SubNote.objects.create(
            note=note,
            item=order_item,
            created_by=User.objects.first())


def reset_courier(courier):
    """gets rid of all the jobs for a courier"""
    for job in Job.objects.get_ongoing().filter(courier=courier):
        job.DoAdminCancel()

    courier.update(num_ongoing_jobs=0)


def generate_api_job(courier):
    job = generate_job(
        courier=courier,
        delivery_type=DELIVERY_TYPE_API,
        fsm_state=DID_ACCEPT_REQUEST)
    job.update(
        manifest_reference='25913909089',
        item_description='1 solid cone\n3 marshmallows')

    return job


def generate_job_from_place(
        place,
        customer=None,
        courier=None,
        order_spec=None,
        use_order_number=False):

    order_spec = order_spec or {
        'custom_order': '1 solid cone\n3 marshmallows',
        'items': [
            {
                'product': CHICKEN_SAUSAGE,
                'quantity': 3,
                'option_groups': [
                    ('Size', ['Bowl'])
                ],
            },
            {
                'product': CHICKEN_SAUSAGE,
                'quantity': 1,
                'option_groups': [
                    ('Size', ['Cup']),
                    ('Salad Dressing', [
                        'Buttermilk Dressing', 'Creole Mustard Dressing'])
                ],
                'special_instructions': (
                    'please keep all the relish out\nim allergic')
            },
            {
                'product': BEIGNET,
                'quantity': 634
            }
        ]
    }

    customer = customer or generate_customer_2(
        business_name='Postmates',
        first_name='Sara',
        last_name='Mauskopf',
        mobile_number='4158482309',
        notes=(
            'Please use the gate buzzer. The entrance is hard to get to, you '
            'have to get past the security guards. They are real tough.'),
        point=Point(-122.397676, 37.775348),
        street_address_1='690 5th St.',
        street_address_2='',
        city='San Francisco',
        state='CA',
        zip_code='94107'
    )

    order_data = generate_orderdata_from_spec(order_spec)

    order = create_order(place, order_data)
    if use_order_number:
        generate_order_number(order)

    item = order.items.first()
    generate_sub_notes(item, ['Subd cup for bowl.', 'Customer doesnt want it'])

    job = generate_job(
        order=order,
        customer=customer,
        courier=courier,
        dropoff_contact=customer.contacts.first(),
        pickup_place=place,
        fsm_state=DID_ACCEPT_REQUEST)

    assign_pickup_info(job)

    return job


def generate_batchable_job(order_spec, customer):
    job = generate_job_from_place(
        get_no_swipe_place(),
        customer=customer,
        courier=None,
        order_spec=order_spec,
        use_order_number=True)


    # assign_pickup_info(job)
    job.order.update(
        state=ORDER_ORDERED,
        ready_dt=datetime.utcnow(),
        ordered_by=User.objects.first())

    return job


def generate_customer_2(
        first_name,
        last_name,
        business_name,
        mobile_number,
        point,
        street_address_1,
        street_address_2='',
        city='San Francisco',
        state='CA',
        zip_code='94110',
        notes=''):

    customer = generate_customer(
        first_name=first_name,
        last_name=last_name,
        phone_number=mobile_number)

    contact = Contact.objects.create(
        customer=customer,
        first_name=first_name,
        last_name=last_name,
        business_name=business_name,
        mobile_number=mobile_number
    )

    zone = get_zone(point)

    address = ContactAddress.objects.create(
        contact=contact,
        zone=zone,
        point=point,
        street_address_1=street_address_1,
        street_address_2=street_address_2,
        notes=notes,
        city=city,
        state=state,
        zip_code=zip_code
    )

    return customer


def load_test_jobs():
    """
    Testing scenarios

    Pickup cases
        gin
        api
        pmc

    Fulfill cases
        gin

    No purchase scenarios
        api
        pmc
        gin
            customer no purchase
            swipe card = false
    """

    courier = Courier.objects.get(user__email='hemant@postmates.com')

    # reset_courier(courier)
    generate_job_from_place(get_order_place(), courier=courier)
    generate_job_from_place(get_no_swipe_place(), courier=courier)
    generate_api_job(courier)


def load_batches():
    """
    creates a batch of 2 jobs for a courier

    we want the same place
    two different customers
    good names
    good dropoff points
    we want order numbers
    we want different items
    jobs should be no purchase

    """
    c1 = generate_customer_2(
        business_name='Postmates',
        first_name='Sara',
        last_name='Mauskopf',
        mobile_number='4158482309',
        notes=(
            'Please use the gate buzzer. The entrance is hard to get to, you '
            'have to get past the security guards. They are real tough.'),
        point=Point(-122.397676, 37.775348),
        street_address_1='690 5th St.',
        street_address_2='',
        city='San Francisco',
        state='CA',
        zip_code='94107'
    )

    c2 = generate_customer_2(
        business_name='',
        first_name='Andrew',
        last_name='Wong',
        mobile_number='6178522509',
        point=Point(-122.414621, 37.758691),
        street_address_1='2413 Folsom St.',
        street_address_2='',
        city='San Francisco',
        state='CA',
        zip_code='94110'
    )

    job1 = generate_batchable_job({
        'custom_order': '',
        'items': [
            {
                'product': CHICKEN_SAUSAGE,
                'quantity': 3,
                'option_groups': [
                    ('Size', ['Bowl'])
                ],
            },
            {
                'product': CHICKEN_SAUSAGE,
                'quantity': 1,
                'option_groups': [
                    ('Size', ['Cup']),
                    ('Salad Dressing', [
                        'Buttermilk Dressing', 'Creole Mustard Dressing'])
                ],
                'special_instructions': (
                    'please keep all the relish out\nim allergic')
            }
        ]
    }, c1)

    job2 = generate_batchable_job({
        'custom_order': '',
        'items': [
            {
                'product': BEIGNET,
                'quantity': 1
            }
        ]
    }, c2)

    courier = Courier.objects.get(user__email='hemant@postmates.com')
    # courier = Courier.objects.get(user__email='jeremy+pm@postmates.com')

    # reset_courier(courier)

    batch = create_from_jobs([job1, job2])
    batch.assign_courier(courier, reassign=True)
    push_auto_assigned_batch(courier, batch)
    return batch