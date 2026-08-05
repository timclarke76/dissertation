#include "histogram.h"

Histogram&
Histogram::operator=(Histogram&& other) noexcept
{
  if (this != &other) {
    if (hist_) {
      hdr_close(hist_);
    }

    hist_ = other.hist_;
    other.hist_ = nullptr;
  }

  return *this;
}
