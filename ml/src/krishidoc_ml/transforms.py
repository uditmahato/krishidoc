"""Aspect-preserving image transforms matching the mobile input contract."""

from __future__ import annotations

from dataclasses import dataclass

from PIL import Image, ImageOps
from torchvision import transforms
from torchvision.transforms import InterpolationMode


IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)
DEFAULT_FILL = tuple(round(channel * 255) for channel in IMAGENET_MEAN)


@dataclass(frozen=True)
class AspectPreservingResize:
    """Resize the long side to ``size`` without changing the aspect ratio."""

    size: int
    interpolation: InterpolationMode = InterpolationMode.BILINEAR

    def __call__(self, image: Image.Image) -> Image.Image:
        if self.size <= 0:
            raise ValueError("Resize size must be positive")
        image = image.convert("RGB")
        width, height = image.size
        if width <= 0 or height <= 0:
            raise ValueError(f"Invalid image dimensions: {image.size}")
        scale = self.size / max(width, height)
        resized_width = max(1, min(self.size, round(width * scale)))
        resized_height = max(1, min(self.size, round(height * scale)))
        return transforms.functional.resize(
            image,
            [resized_height, resized_width],
            interpolation=self.interpolation,
            antialias=True,
        )


@dataclass(frozen=True)
class SymmetricPadToSquare:
    """Pad an already resized image to a square mobile-model input."""

    size: int
    fill: tuple[int, int, int] = DEFAULT_FILL

    def __call__(self, image: Image.Image) -> Image.Image:
        if self.size <= 0:
            raise ValueError("Padding size must be positive")
        image = image.convert("RGB")
        resized_width, resized_height = image.size
        if (
            resized_width <= 0
            or resized_height <= 0
            or resized_width > self.size
            or resized_height > self.size
        ):
            raise ValueError(
                f"Image dimensions must be within {self.size}x{self.size}: {image.size}"
            )
        horizontal = self.size - resized_width
        vertical = self.size - resized_height
        padding = (
            horizontal // 2,
            vertical // 2,
            horizontal - horizontal // 2,
            vertical - vertical // 2,
        )
        return ImageOps.expand(image, border=padding, fill=self.fill)


@dataclass(frozen=True)
class AspectPreservingLetterbox:
    """Resize the long side to ``size`` and symmetrically pad the short side."""

    size: int
    fill: tuple[int, int, int] = DEFAULT_FILL
    interpolation: InterpolationMode = InterpolationMode.BILINEAR

    def __call__(self, image: Image.Image) -> Image.Image:
        resized = AspectPreservingResize(
            self.size,
            interpolation=self.interpolation,
        )(image)
        return SymmetricPadToSquare(self.size, fill=self.fill)(resized)


def build_transform(image_size: int, training: bool):
    operations: list[object]
    if training:
        # Perform the only resolution-dependent work before augmentation.  Many
        # field sources contain multi-megapixel images while the mobile model
        # consumes only ``image_size`` pixels on its long edge.  Isotropic
        # resizing commutes with the geometric intent of these modest
        # augmentations, so rotating and colour-jittering the downsized content
        # avoids processing millions of pixels that the model never observes.
        # Padding deliberately remains last: its fixed ImageNet-mean colour is
        # part of the inference/mobile input contract and must not be jittered.
        operations = [
            AspectPreservingResize(image_size),
            transforms.RandomHorizontalFlip(p=0.5),
            transforms.RandomRotation(
                degrees=8,
                interpolation=InterpolationMode.BILINEAR,
                fill=DEFAULT_FILL,
            ),
            transforms.ColorJitter(
                brightness=0.15,
                contrast=0.15,
                saturation=0.12,
                hue=0.02,
            ),
            SymmetricPadToSquare(image_size),
        ]
    else:
        operations = [AspectPreservingLetterbox(image_size)]
    operations.extend(
        [
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ]
    )
    return transforms.Compose(operations)
