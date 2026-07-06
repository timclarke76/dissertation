def saturating_sub(a, b):
    """Performs a saturating subtraction of two unsigned numbers.

    If `a` is greater than `b`, it returns the result of `a - b`. If `a` is less
    than or equal to `b`, it returns zero instead of underflowing.

    Args:
        a: The number from which `b` is to be subtracted.
        b: The number to be subtracted.

    Returns:
        The result of the subtraction if `a > b`, otherwise zero."""

    return (a - b) if a > b else 0
