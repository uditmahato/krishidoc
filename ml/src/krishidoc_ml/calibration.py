"""Post-hoc temperature and conservative open-set gate calibration."""

from __future__ import annotations

from typing import Any

import numpy as np
import torch
from torch.nn import functional as F

from .constants import USABLE_VALIDITY_LABEL, VALIDITY_TO_INDEX
from .metrics import energy_score, softmax


def fit_temperature(
    logits: np.ndarray,
    targets: np.ndarray,
    *,
    maximum_iterations: int = 100,
) -> float:
    """Fit one positive scalar temperature by validation-set NLL."""

    logits_tensor = torch.as_tensor(logits, dtype=torch.float64)
    targets_tensor = torch.as_tensor(targets, dtype=torch.long)
    if len(targets_tensor) == 0:
        return 1.0
    log_temperature = torch.nn.Parameter(torch.zeros((), dtype=torch.float64))
    optimizer = torch.optim.LBFGS(
        [log_temperature], lr=0.1, max_iter=maximum_iterations, line_search_fn="strong_wolfe"
    )

    def closure() -> torch.Tensor:
        optimizer.zero_grad()
        temperature = log_temperature.exp().clamp(0.05, 20.0)
        loss = F.cross_entropy(logits_tensor / temperature, targets_tensor)
        loss.backward()
        return loss

    optimizer.step(closure)
    return float(log_temperature.detach().exp().clamp(0.05, 20.0).item())


def fit_calibration(
    *,
    validity_logits: np.ndarray,
    condition_logits: np.ndarray,
    validity_targets: np.ndarray,
    condition_targets: np.ndarray,
    target_false_accept_rate: float = 0.05,
) -> dict[str, Any]:
    """Fit temperatures and a three-signal refusal gate on validation only."""

    validity_targets = np.asarray(validity_targets, dtype=np.int64)
    condition_targets = np.asarray(condition_targets, dtype=np.int64)
    usable_index = VALIDITY_TO_INDEX[USABLE_VALIDITY_LABEL]
    known = (validity_targets == usable_index) & (condition_targets >= 0)
    ood = ~known

    validity_temperature = fit_temperature(validity_logits, validity_targets)
    condition_temperature = fit_temperature(
        np.asarray(condition_logits)[known], condition_targets[known]
    )
    validity_probability = softmax(validity_logits, validity_temperature)[:, usable_index]
    condition_probability = softmax(condition_logits, condition_temperature).max(axis=1)
    energy = energy_score(condition_logits, condition_temperature)

    thresholds = _select_gate_thresholds(
        validity_probability=validity_probability,
        condition_probability=condition_probability,
        energy=energy,
        known=known,
        ood=ood,
        target_false_accept_rate=target_false_accept_rate,
    )
    return {
        "schema_version": 1,
        "method": "scalar_temperature_plus_three_signal_grid_gate",
        "validity_temperature": validity_temperature,
        "condition_temperature": condition_temperature,
        "thresholds": thresholds,
        "validation_counts": {
            "total": int(len(known)),
            "known": int(np.sum(known)),
            "ood": int(np.sum(ood)),
        },
        "limitations": [
            "Thresholds are valid only for the recorded crop, model, and data domain.",
            "A locked Nepal field set is still required before confident-result UX.",
        ],
    }


def apply_calibration(
    calibration: dict[str, Any],
    validity_logits: np.ndarray,
    condition_logits: np.ndarray,
) -> dict[str, np.ndarray]:
    validity_temperature = float(calibration["validity_temperature"])
    condition_temperature = float(calibration["condition_temperature"])
    thresholds = calibration["thresholds"]
    usable_index = VALIDITY_TO_INDEX[USABLE_VALIDITY_LABEL]
    validity_probabilities = softmax(validity_logits, validity_temperature)
    condition_probabilities = softmax(condition_logits, condition_temperature)
    validity_probability = validity_probabilities[:, usable_index]
    condition_probability = condition_probabilities.max(axis=1)
    energy = energy_score(condition_logits, condition_temperature)
    accepted = (
        (validity_probability >= float(thresholds["validity_probability_min"]))
        & (condition_probability >= float(thresholds["condition_probability_min"]))
        & (energy <= float(thresholds["condition_energy_max"]))
    )
    return {
        "validity_probabilities": validity_probabilities,
        "condition_probabilities": condition_probabilities,
        "validity_probability": validity_probability,
        "condition_probability": condition_probability,
        "condition_energy": energy,
        "accepted": accepted,
    }


def _select_gate_thresholds(
    *,
    validity_probability: np.ndarray,
    condition_probability: np.ndarray,
    energy: np.ndarray,
    known: np.ndarray,
    ood: np.ndarray,
    target_false_accept_rate: float,
) -> dict[str, Any]:
    if not 0.0 <= target_false_accept_rate <= 1.0:
        raise ValueError("target_false_accept_rate must be between zero and one")
    if not np.any(known):
        raise ValueError("Calibration requires at least one known usable target leaf")

    validity_candidates = _threshold_candidates(
        validity_probability, higher_is_accept=True
    )
    condition_candidates = _threshold_candidates(
        condition_probability, higher_is_accept=True
    )
    energy_candidates = _threshold_candidates(energy, higher_is_accept=False)

    best: tuple[float, float, float, float, float] | None = None
    # Score tuple: known acceptance (max), OOD acceptance (min), then the three
    # thresholds. Candidate grids are deliberately bounded for reproducibility.
    for validity_min in validity_candidates:
        validity_accept = validity_probability >= validity_min
        for condition_min in condition_candidates:
            partial = validity_accept & (condition_probability >= condition_min)
            for energy_max in energy_candidates:
                accepted = partial & (energy <= energy_max)
                known_accept = float(np.mean(accepted[known]))
                ood_accept = float(np.mean(accepted[ood])) if np.any(ood) else 0.0
                if ood_accept > target_false_accept_rate + 1e-12:
                    continue
                candidate = (
                    known_accept,
                    -ood_accept,
                    float(validity_min),
                    float(condition_min),
                    -float(energy_max),
                )
                if best is None or candidate > best:
                    best = candidate

    if best is None:
        # Finite grids always contain an all-refuse policy, but retain an
        # explicit conservative fallback in case non-finite upstream scores are
        # encountered.
        best = (0.0, 0.0, 1.0, 1.0, -float(np.min(energy) - 1e-6))

    known_accept, negative_ood_accept, validity_min, condition_min, negative_energy_max = best
    return {
        "validity_probability_min": validity_min,
        "condition_probability_min": condition_min,
        "condition_energy_max": -negative_energy_max,
        "target_false_accept_rate": float(target_false_accept_rate),
        "observed_false_accept_rate": float(-negative_ood_accept),
        "known_accept_rate": float(known_accept),
        "selection_objective": "maximise known acceptance subject to OOD FAR cap",
    }


def _threshold_candidates(values: np.ndarray, *, higher_is_accept: bool) -> np.ndarray:
    values = np.asarray(values, dtype=np.float64)
    finite = values[np.isfinite(values)]
    if not len(finite):
        raise ValueError("Cannot calibrate thresholds from non-finite scores")
    quantiles = np.quantile(finite, np.linspace(0.0, 1.0, 11))
    epsilon = max(1e-9, float(np.ptp(finite)) * 1e-9)
    if higher_is_accept:
        extras = np.array([0.0, 0.5, 0.8, 0.9, 0.95, float(finite.max() + epsilon)])
    else:
        extras = np.array(
            [float(finite.min() - epsilon), *quantiles.tolist(), float(finite.max() + epsilon)]
        )
    return np.unique(np.concatenate((quantiles, extras)))
