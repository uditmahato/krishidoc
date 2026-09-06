"""Crop-specific single-pass, two-head image classifiers."""

from __future__ import annotations

from typing import Literal

import torch
from torch import nn
from torchvision import models

from .constants import VALIDITY_LABELS

Architecture = Literal["mobilenet_v3_large", "efficientnet_b0"]


class CropSpecificTwoHeadModel(nn.Module):
    """One visual encoder with raw-logit validity and condition heads."""

    def __init__(
        self,
        architecture: Architecture,
        num_condition_classes: int,
        pretrained: bool = True,
    ) -> None:
        super().__init__()
        if num_condition_classes < 2:
            raise ValueError("A condition head requires at least two classes")
        self.architecture = architecture
        self.num_condition_classes = int(num_condition_classes)

        if architecture == "mobilenet_v3_large":
            weights = models.MobileNet_V3_Large_Weights.DEFAULT if pretrained else None
            network = models.mobilenet_v3_large(weights=weights)
            self.backbone = network.features
            self.pool = network.avgpool
            self.shared = nn.Sequential(*list(network.classifier.children())[:-1])
            head_features = network.classifier[-1].in_features
        elif architecture == "efficientnet_b0":
            weights = models.EfficientNet_B0_Weights.DEFAULT if pretrained else None
            network = models.efficientnet_b0(weights=weights)
            self.backbone = network.features
            self.pool = network.avgpool
            self.shared = nn.Sequential(*list(network.classifier.children())[:-1])
            head_features = network.classifier[-1].in_features
        else:
            raise ValueError(f"Unsupported architecture: {architecture}")

        self.validity_head = nn.Linear(head_features, len(VALIDITY_LABELS))
        self.condition_head = nn.Linear(head_features, num_condition_classes)
        nn.init.normal_(self.validity_head.weight, mean=0.0, std=0.01)
        nn.init.zeros_(self.validity_head.bias)
        nn.init.normal_(self.condition_head.weight, mean=0.0, std=0.01)
        nn.init.zeros_(self.condition_head.bias)

    def forward(self, images: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        features = self.backbone(images)
        features = self.pool(features)
        features = torch.flatten(features, 1)
        features = self.shared(features)
        # These remain raw logits. Temperature scaling and softmax belong to the
        # evaluated decision policy, never inside the trainable model graph.
        return self.validity_head(features), self.condition_head(features)

    def set_backbone_trainable(self, trainable: bool) -> None:
        for parameter in self.backbone.parameters():
            parameter.requires_grad = trainable


def create_model(
    architecture: Architecture,
    num_condition_classes: int,
    pretrained: bool = True,
) -> CropSpecificTwoHeadModel:
    return CropSpecificTwoHeadModel(
        architecture=architecture,
        num_condition_classes=num_condition_classes,
        pretrained=pretrained,
    )
