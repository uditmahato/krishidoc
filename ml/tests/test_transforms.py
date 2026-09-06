from __future__ import annotations

from PIL import Image
import torch
from torchvision import transforms as tv_transforms

from krishidoc_ml.transforms import (
    DEFAULT_FILL,
    IMAGENET_MEAN,
    IMAGENET_STD,
    AspectPreservingLetterbox,
    AspectPreservingResize,
    SymmetricPadToSquare,
    build_transform,
)


def test_letterbox_preserves_content_aspect_and_centers_padding() -> None:
    image = Image.new("RGB", (100, 200), color=(255, 0, 0))
    result = AspectPreservingLetterbox(224, fill=(0, 0, 0))(image)
    assert result.size == (224, 224)
    # 100x200 becomes 112x224: 56 black pixels on each horizontal side.
    assert result.getpixel((0, 100)) == (0, 0, 0)
    assert result.getpixel((55, 100)) == (0, 0, 0)
    assert result.getpixel((56, 100))[0] > 200
    assert result.getpixel((167, 100))[0] > 200
    assert result.getpixel((168, 100)) == (0, 0, 0)


def test_training_resizes_before_resolution_dependent_augmentation() -> None:
    transform = build_transform(224, training=True)

    assert [type(operation) for operation in transform.transforms] == [
        AspectPreservingResize,
        tv_transforms.RandomHorizontalFlip,
        tv_transforms.RandomRotation,
        tv_transforms.ColorJitter,
        SymmetricPadToSquare,
        tv_transforms.ToTensor,
        tv_transforms.Normalize,
    ]


def test_training_padding_keeps_mobile_fill_after_colour_jitter() -> None:
    # A portrait image leaves a broad outer gutter.  That gutter is added after
    # augmentation, so its value remains the fixed mobile preprocessing fill.
    image = Image.new("RGB", (1000, 2000), color=(240, 40, 20))
    torch.manual_seed(9)

    result = build_transform(224, training=True)(image)

    expected_fill = torch.tensor(
        [
            (channel / 255.0 - mean) / std
            for channel, mean, std in zip(DEFAULT_FILL, IMAGENET_MEAN, IMAGENET_STD)
        ],
        dtype=result.dtype,
    )
    assert result.shape == (3, 224, 224)
    assert torch.allclose(result[:, 112, 0], expected_fill, atol=1e-6)


def test_inference_still_uses_single_letterbox_contract() -> None:
    transform = build_transform(224, training=False)

    assert isinstance(transform.transforms[0], AspectPreservingLetterbox)
    assert transform(Image.new("RGB", (120, 80))).shape == (3, 224, 224)
