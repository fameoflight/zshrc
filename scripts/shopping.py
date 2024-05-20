from core.models import (
    DID_DISPATCH_REQUEST,
    DELIVERY_TYPE_API,
    DELIVERY_TYPE_GIN
)

from core.models import Courier, Job

from core.util.tests import generate_job

from batch.models import Batch, BatchJob

from core.util.tests import generate_job, generate_delivery_info
from core.models import DELIVERY_TYPE_API, DID_ACCEPT_REQUEST
from batch.models import Batch

from datetime import datetime, timedelta
from decimal import Decimal
from pm_base.testcases import TestCase

from core.models import (
    DELIVERY_TYPE_API,
    ORDER_UNCLAIMED,
    ORDER_CLAIMED,
    ORDER_ORDERED,
    ORDER_ASSIGNED_TO_COURIER,
    ProductOption,
    ProductOptionGroup,
    OrderItemOption,
    SubNote)
from core.util.orders import update_order
from core.util.products import (
    create_product_category,
    create_product,
    LEAVE_OUT_TYPE,
    LEAVE_OUT_TEXT)
from core.util.serializers.img import ImgSerializer
from core.util.tests import (
    generate_img,
    generate_catalog,
    generate_place,
    generate_customer,
    generate_job,
    generate_order,)

from batch.manifest import (
    CustomOrderItem,
    SimpleLineItem,
    LineItemSerializer,
    ManifestSerializer)

def generate_job1():
    hemant = Courier.objects.get(user__email='hemant@postmates.com')

    pickup_info = generate_delivery_info()

    j1 = generate_job(
        courier=hemant,
        pickup_info=pickup_info,
        delivery_type=DELIVERY_TYPE_API,
        fsm_state=DID_ACCEPT_REQUEST)

    j1.update(item_description="blah0\nblah1", manifest_reference='123')

def generate_job2():
    place = generate_place()
    customer = generate_customer()
    catalog = generate_catalog(place=place)
    category = create_product_category(catalog, 'test_cat')
    custom_order = u'custom_order_0\ncustom_order_1'
    products = []
    product_names = []
    for i in range(3):
        product_name = u'product_{}'.format(i)
        product_names.append(product_name)
        products.append(
            create_product(category, product_name, base_price=i))
    order = generate_order(customer, place, products, custom_order)

    hemant = Courier.objects.get(user__email='hemant@postmates.com')

    pickup_info = generate_delivery_info()

    j1 = generate_job(
        order=order,
        courier=hemant,
        pickup_info=pickup_info,
        delivery_type=DELIVERY_TYPE_API,
        fsm_state=DID_ACCEPT_REQUEST)

def generate_job3():
    place = generate_place()
    customer = generate_customer()
    custom_order = u'custom_order_0\ncustom_order_1'
    order = generate_order(customer, place, custom_order=custom_order)

    hemant = Courier.objects.get(user__email='hemant@postmates.com')

    pickup_info = generate_delivery_info()
    j1 = generate_job(
        order=order,
        courier=hemant,
        pickup_info=pickup_info,
        delivery_type=DELIVERY_TYPE_GIN,
        fsm_state=DID_ACCEPT_REQUEST)

def generate_job4():
    place = generate_place()
    customer = generate_customer()
    catalog = generate_catalog(place=place)
    category = create_product_category(catalog, 'test_cat')
    img = generate_img()
    product = create_product(category, 'product_a', base_price=10.00)
    product.update(img=img)
    order = generate_order(
        customer, place, [product], sub_choice=LEAVE_OUT_TYPE)
    order_item = order.items.first()
    product_option_group = ProductOptionGroup.objects.create(
        catalog=catalog, name='test_group', admin_label='admin_label')
    product_option = ProductOption.objects.create(
        name='p_option',
        price=Decimal('1.00'),
        group=product_option_group)
    OrderItemOption.objects.create(
        item=order.items.first(),
        source_option=product_option,
        name="a_option",
        price=Decimal('2.00'),
        group_name='option_group',
        source_group=product_option_group)
    OrderItemOption.objects.create(
        item=order.items.first(),
        source_option=product_option,
        name="b_option",
        price=Decimal('2.00'),
        group_name='option_group',
        source_group=product_option_group)
    OrderItemOption.objects.create(
        item=order.items.first(),
        source_option=product_option,
        name="c_option",
        price=Decimal('2.00'),
        group_name='option_group_2',
        source_group=product_option_group)
    sub_notes = [
        SubNote.objects.create(
            note=str(i),
            item=order_item,
            created_by=customer.user) for i in range(2)
        ]

    hemant = Courier.objects.get(user__email='hemant@postmates.com')

    pickup_info = generate_delivery_info()
    j1 = generate_job(
        order=order,
        courier=hemant,
        pickup_info=pickup_info,
        delivery_type=DELIVERY_TYPE_GIN,
        fsm_state=DID_ACCEPT_REQUEST)



