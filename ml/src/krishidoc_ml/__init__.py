"""Training and evaluation primitives for KrishiDoc field-model candidates.

This package deliberately does not mutate the Flutter application's bundled
model.  It produces auditable candidates which still require the documented
field, calibration, quantisation, and device gates before promotion.
"""

from .constants import USABLE_VALIDITY_LABEL, VALIDITY_LABELS
from .model import CropSpecificTwoHeadModel, create_model

__all__ = [
    "CropSpecificTwoHeadModel",
    "USABLE_VALIDITY_LABEL",
    "VALIDITY_LABELS",
    "create_model",
]

__version__ = "0.1.0"
