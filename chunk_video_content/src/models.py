from typing import Iterator, Optional
from pydantic import BaseModel, Field

class Size(BaseModel):
    width: int = Field(gt=0, description="Width must be a positive integer")
    height: int = Field(gt=0, description="Height must be a positive integer")

    def __iter__(self) -> Iterator[int]:
        """Allow iteration over the size, yielding width then height."""
        yield self.width
        yield self.height

    def scale(
        self,
        scale_factor: Optional[float] = None,
        min_width: Optional[int] = None,
        min_height: Optional[int] = None,
    ) -> "Size":
        """
        Scale the Size instance either by a given scale factor or to satisfy
        minimum width/height constraints while preserving the aspect ratio.

        Parameters:
            scale_factor (Optional[float]): The factor by which to multiply the dimensions.
            min_width (Optional[int]): The minimum desired width.
            min_height (Optional[int]): The minimum desired height.

        Returns:
            Size: A new Size instance with the scaled dimensions.

        Raises:
            ValueError: If neither scale_factor nor at least one of min_width/min_height is provided.
        """
        if scale_factor is not None:
            new_width = int(self.width * scale_factor)
            new_height = int(self.height * scale_factor)
        elif min_width is not None or min_height is not None:
            factor_w = min_width / self.width if min_width is not None else 1
            factor_h = min_height / self.height if min_height is not None else 1
            # Use the larger scale factor to ensure both dimensions meet the minimum.
            scale_factor = max(factor_w, factor_h)
            new_width = int(self.width * scale_factor)
            new_height = int(self.height * scale_factor)
        else:
            raise ValueError("You must provide either a scale_factor or at least one of min_width/min_height")

        return Size(width=new_width, height=new_height)

    def __repr__(self) -> str:
        return f"Size(width={self.width}, height={self.height})"
