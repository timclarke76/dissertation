#include "histogram.h"

Histogram&
Histogram::operator=(Histogram&& other) noexcept
{
  if (this != &other) {
    if (hist_) {
      free(hist_);
    }

    hist_ = other.hist_;
    other.hist_ = nullptr;
  }

  return *this;
}
