#pragma once

#include <string>

#include <toml++/toml.h>

#include "args.h"
#include "policy.h"

/// \brief Represents the configuration settings for the application.
class Settings
{
public:
  /// \brief Represents the configuration for an event queue.
  struct QueueConfig
  {
    /// The name of the queue.
    std::string name;

    /// The capacity of the queue in frames.
    size_t capacity_frames;
  };

public:
  /// \brief Creates a new `Settings` instance by loading configuration from a
  /// TOML file specified by the `args` argument, and applying command-line
  /// arguments.
  ///
  /// If a setting is provided in the command-line arguments, it will override
  /// the corresponding value from the configuration file.
  ///
  /// \param args The command-line arguments that supplies the settings
  /// filename, and may override configuration settings.
  ///
  /// \return A `Result` containing the `Settings` instance if successful, or an
  /// error if the configuration could not be loaded or deserialized.
  Settings(const Args& args);

private:
  /// \brief Parses the event queue configuration from a TOML table.
  ///
  /// \param tbl The TOML table containing the event queue configuration.
  /// \param config_name The name of the configuration to parse.
  /// \return A `QueueConfig` instance containing the parsed configuration.
  static QueueConfig parse_event_queue_config(const toml::table& tbl,
    const std::string& config_name);

  /// \brief Parses the policy configuration from a TOML table.
  ///
  /// \param tbl The TOML table containing the policy configuration.
  /// \param policy_name The name of the policy to parse.
  /// \return A `Policy` instance containing the parsed policy.
  static Policy parse_policy(const toml::table& tbl,
    const std::string& policy_name);

public:
  /// Configuration for the RGB event queue.
  QueueConfig rgb_queue_config;

  /// Policy for handling RGB events.
  Policy rgb_policy;

  /// Configuration for the accelerometer event queue.
  QueueConfig accel_queue_config;

  /// Policy for handling accelerometer events.
  Policy accelerometer_policy;

  /// Configuration for the gyroscope event queue.
  QueueConfig gyro_queue_config;

  /// Policy for handling gyroscope events.
  Policy gyroscope_policy;
};
