#pragma once
#include <stdexcept>

#include <hdr_histogram.h>

/// \brief A wrapper class for the HdrHistogram library, providing a convenient
/// interface for recording and querying latency measurements.
class Histogram
{
public:
  /// \brief Constructs a new Histogram instance with the specified parameters.
  ///
  /// \param min The minimum value that can be recorded in the histogram.
  /// \param max The maximum value that can be recorded in the histogram.
  /// \param precision The number of significant figures to maintain in the
  /// histogram.
  Histogram(const int64_t min = 1,
    const int64_t max = 60'000'000'000LL,
    const int precision = 3)
  {
    if (hdr_init(min, max, precision, &hist_) != 0) {
      throw std::runtime_error("Failed to initialize HdrHistogram");
    }
  }

  /// \brief Destructor to free the allocated histogram memory.
  ~Histogram()
  {
    if (hist_) {
      free(hist_);
    }
  }

  /// \brief Move constructor to transfer ownership of the enclosed histogram.
  ///
  /// \param other The Histogram object to move from.
  Histogram(Histogram&& other) noexcept
    : hist_(other.hist_)
  {
    other.hist_ = nullptr;
  }

  /// \brief Move assignment operator to transfer ownership of the enclosed
  /// histogram.
  ///
  /// \param other The Histogram object to move from.
  Histogram& operator=(Histogram&& other) noexcept;

  // Delete copy constructor and copy assignment operator to prevent copying.
  Histogram(const Histogram&) = delete;
  Histogram& operator=(const Histogram&) = delete;

  /// \brief Record a value in the enclosed histogram.
  ///
  /// \param value The value to record.
  void record(uint64_t value) { hdr_record_value(hist_, value); }

  /// \brief Reset the enclosed histogram, clearing all recorded values.
  void reset() { hdr_reset(hist_); }

  /// \brief Get the value at a specific percentile in the enclosed histogram.
  ///
  /// \param percentile The percentile to query (0.0 to 100.0).
  /// \return The value at the specified percentile.
  double value_at_percentile(const double percentile) const
  {
    return hdr_value_at_percentile(hist_, percentile);
  }

  /// \brief Get the maximum recorded value in the enclosed histogram.
  ///
  /// \return The maximum recorded value.
  uint64_t max() const { return hdr_max(hist_); }

private:
  /// \brief Pointer to the underlying HdrHistogram structure.
  struct hdr_histogram* hist_ = nullptr;
};
