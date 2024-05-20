from __future__ import absolute_import
from datetime import datetime, timedelta
import time

from collections import Counter

from core.util.markets import get_active_markets
from dradis.errors import CriticalError, WarningError
from courier_dispatch.models import FindCourierRequest, CourierDispatch
from courier_dispatch.tasks import loop_ts_cache

CRITICAL_THRESHOLD_TD = timedelta(seconds=30)
WARNING_THRESHOLD_TD = timedelta(seconds=15)

DISPATCH_CHECK_THRESH = 20
DISPATCH_CHECK_TD = timedelta(minutes=10)
CRITICAL_CANCELED_DISPATCH_PCT = 95
WARNING_CANCELED_DISPATCH_PCT = 85

expire_dt = datetime.utcnow() - WARNING_THRESHOLD_TD
not_expired = (
    FindCourierRequest.objects.filter(
        state=FindCourierRequest.STATE_OPEN,
        expire_dt__lt=expire_dt)
    .order_by('expire_dt'))

print not_expired.count()