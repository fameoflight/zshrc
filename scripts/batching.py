from core.models import (
    DID_DISPATCH_REQUEST,
    DELIVERY_TYPE_API
)

from core.models import Courier, Job, DeliveryInfo

from core.util.tests import generate_job

from batch.models import Batch, BatchJob

from core.util.tests import generate_job
from core.models import DELIVERY_TYPE_API, DID_ACCEPT_REQUEST
from batch.models import Batch


from batch.batcher import (
    group_jobs,
    create_from_jobs)

from random import randint


def get_pickup_info():
    return DeliveryInfo.objects.filter(business_name='KIF Place with list catalog', city='San Francisco')[0]

def get_dropoff_info():
    count = DeliveryInfo.objects.filter(city='San Francisco').count()
    index = randint(0, count-1)
    return DeliveryInfo.objects.filter(city='San Francisco')[index].source_address

def make_batch(courier, n):
    # create single pickup delivery address
    # 2 different dropoffs, 2 different customers

    jobs = []
    for i in range(n):
        j1 = generate_job(
            pickup_info=get_pickup_info(),
            dropoff_contact_address=get_dropoff_info(),
            delivery_type=DELIVERY_TYPE_API,
            fsm_state=DID_ACCEPT_REQUEST)
        jobs.append(j1)

    batch = create_from_jobs(jobs)
    batch.assign_courier(courier)
    return batch

def make_batch_for_hemant():
    hemant = Courier.objects.get(user__email='hemant@postmates.com')
    make_batch(hemant, 4)
    
