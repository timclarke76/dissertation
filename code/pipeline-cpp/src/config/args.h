#pragma once
#include <string>

#include <argparse/argparse.hpp>

/// \brief Parses command line arguments for the application.
///
/// If the `--settings` argument is not provided, it defaults to
/// "settings.toml".
class Args
{
public:
  /// \brief Constructs an Args object and parses command line arguments.
  ///
  /// Initialises an ArgumentParser, adds the expected command line arguments,
  /// and parses the provided arguments.
  ///
  /// \param argc The number of command line arguments.
  /// \param argv The array of command line argument strings.
  Args(const int argc, const char* const* argv);

  /// \brief Returns the name of the settings file.
  ///
  /// \return The name of the settings file as a string.
  std::string settings() const { return settings_; }

private:
  /// The name of the settings file.
  std::string settings_;
};
