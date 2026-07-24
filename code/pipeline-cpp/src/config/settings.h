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
  struct EventQueueConfig
  {
    /// The name of the queue.
    std::string name;

    /// The target frame rate for the queue in frames per second.
    size_t fps;

    /// The capacity of the queue in frames.
    size_t capacity_frames;

    /// The shape of the frames in the queue, suitable for tensor.
    std::vector<int64_t> frame_shape;

    /// The size of each frame item in bytes (e.g. 1 byte for uint8_t, 4 bytes
    /// for float).
    size_t item_size_bytes;
  };

public:
  /// \brief Creates a new Settings instance by loading configuration from a
  /// TOML file specified by the args argument, and applying command-line
  /// arguments.
  ///
  /// If a setting is provided in the command-line arguments, it will override
  /// the corresponding value from the configuration file.
  ///
  /// \param args The command-line arguments that may override configuration
  /// settings.
  Settings(const Args& args);

  /// \brief Returns the configuration for the RGB event queue.
  ///
  /// \return The EventQueueConfig for the RGB event queue.
  const EventQueueConfig& get_rgb_queue_config() const
  {
    return rgb_queue_config;
  }

  /// \brief Returns the policy for handling RGB events.
  ///
  /// \return The Policy for handling RGB events.
  const Policy& get_rgb_policy() const { return rgb_policy; }

  /// \brief Returns the configuration for the accelerometer event queue.
  ///
  /// \return The EventQueueConfig for the accelerometer event queue.
  const EventQueueConfig& get_accel_queue_config() const
  {
    return accel_queue_config;
  }

  /// \brief Returns the policy for handling accelerometer events.
  ///
  /// \return The Policy for handling accelerometer events.
  const Policy& get_accel_policy() const { return accel_policy; }

  /// \brief Returns the configuration for the gyroscope event queue.
  ///
  /// \return The EventQueueConfig for the gyroscope event queue.
  const EventQueueConfig& get_gyro_queue_config() const
  {
    return gyro_queue_config;
  }

  /// \brief Returns the policy for handling gyroscope events.
  ///
  /// \return The Policy for handling gyroscope events.
  const Policy& get_gyro_policy() const { return gyro_policy; }

private:
  /// \brief Parses the event queue configuration from a TOML table.
  ///
  /// \param tbl The TOML table containing the event queue configuration.
  /// \param config_name The name of the configuration to parse.
  /// \return An EventQueueConfig instance containing the parsed configuration.
  static EventQueueConfig parse_event_queue_config(const toml::table& tbl,
    const std::string& config_name);

  /// \brief Parses the policy configuration from a TOML table.
  ///
  /// \param tbl The TOML table containing the policy configuration.
  /// \param policy_name The name of the policy to parse.
  /// \return A Policy instance containing the parsed policy.
  static Policy parse_policy(const toml::table& tbl,
    const std::string& policy_name);

private:
  /// Configuration for the RGB event queue.
  EventQueueConfig rgb_queue_config;

  /// Policy for handling RGB events.
  Policy rgb_policy;

  /// Configuration for the accelerometer event queue.
  EventQueueConfig accel_queue_config;

  /// Policy for handling accelerometer events.
  Policy accel_policy;

  /// Configuration for the gyroscope event queue.
  EventQueueConfig gyro_queue_config;

  /// Policy for handling gyroscope events.
  Policy gyro_policy;
};
