from core.models import (
    DID_ACCEPT_REQUEST,
    DELIVERY_TYPE_API
)

from core.models import (
    Courier,
    Job,
    SubNote,
    Catalog,
    Product
)
from core.util.orders import (
    assign_pickup_info
)
from core.util.products import (
    create_order
)

from core.util.tests import (
    generate_place,
    generate_job,
    generate_orderdata,
    add_product_to_orderdata)

from place.models import Place, OrderChannel, PlacePricing
from pm_user.models import User


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
    PlacePricing.objects.create(place=place, swipe_card=False)
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


def generate_job_from_place(place, courier):
    order_data = generate_orderdata_from_spec({
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
    })

    order = create_order(place, order_data)

    item = order.items.first()
    generate_sub_notes(item, ['Subd cup for bowl.', 'Customer doesnt want it'])

    job = generate_job(
        order=order,
        courier=courier,
        pickup_place=place,
        fsm_state=DID_ACCEPT_REQUEST)

    assign_pickup_info(job)
    return job


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
    generate_job_from_place(get_order_place(), courier)
    generate_job_from_place(get_no_swipe_place(), courier)
    generate_job_from_place(get_cot_place(), courier)
    generate_api_job(courier)

