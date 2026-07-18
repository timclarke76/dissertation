#include <format>

#include "settings.h"

Settings::Settings(const Args& args)
{
  std::string source = args.settings();

  try {
    auto settings = toml::parse_file(source);

    rgb_queue_config = parse_event_queue_config(settings, "rgb_queue_config");
    rgb_policy = parse_policy(settings, "rgb_policy");

    accel_queue_config =
      parse_event_queue_config(settings, "accel_queue_config");
    accel_policy = parse_policy(settings, "accel_policy");

    gyro_queue_config = parse_event_queue_config(settings, "gyro_queue_config");
    gyro_policy = parse_policy(settings, "gyro_policy");
  } catch (const toml::parse_error& e) {
    throw std::runtime_error(
      std::format("Settings file '{}' parsing failed: {}", source, e.what()));
  }
}

Settings::EventQueueConfig
Settings::parse_event_queue_config(const toml::table& tbl_in,
  const std::string& config_name)
{
  if (auto tbl = tbl_in[config_name].as_table()) {
    EventQueueConfig config;

    if (auto name_node = (*tbl)["name"].as_string()) {
      config.name = name_node->get();
    } else {
      throw std::runtime_error(
        std::format("Missing or invalid 'name' in {}", config_name));
    }

    if (auto fps_node = (*tbl)["fps"].as<int64_t>()) {
      config.fps = static_cast<size_t>(fps_node->get());
    } else {
      throw std::runtime_error(
        std::format("Missing or invalid 'fps' in {}", config_name));
    }

    if (auto cap_node = (*tbl)["capacity_frames"].as<int64_t>()) {
      config.capacity_frames = static_cast<size_t>(cap_node->get());
    } else {
      throw std::runtime_error(
        std::format("Missing or invalid 'capacity_frames' in {}", config_name));
    }

    return config;
  } else {
    throw std::runtime_error(std::format(
      "Missing or invalid table '{}' in settings file", config_name));
  }
}

Policy
Settings::parse_policy(const toml::table& tbl_in,
  const std::string& policy_name)
{
  auto tbl = tbl_in[policy_name].as_table();

  if (!tbl) {
    throw std::runtime_error(std::format(
      "Missing or invalid table '{}' in settings file", policy_name));
  }

  auto type_node = (*tbl)["type"].as_string();

  if (!type_node) {
    throw std::runtime_error(
      std::format("Missing or invalid 'type' in {}", policy_name));
  }

  auto type_str = type_node->get();

  if (type_str == "BoundedQueue") {
    return BoundedQueue{};
  } else if (type_str == "ExponentialBackoff") {
    return ExponentialBackoff{ static_cast<uint64_t>(
                                 (*tbl)["base_nanos"].as<int64_t>()->get()),
      (*tbl)["max_nanos"].as<double>()->get(),
      (*tbl)["multiplier"].as<double>()->get() };
  } else if (type_str == "DropOldest") {
    return DropOldest{};
  } else if (type_str == "DropNewest") {
    return DropNewest{};
  } else if (type_str == "AdaptiveDecimation") {
    return AdaptiveDecimation{ static_cast<size_t>(
                                 (*tbl)["threshold"].as<int64_t>()->get()),
      static_cast<size_t>((*tbl)["min_ratio"].as<int64_t>()->get()),
      static_cast<size_t>((*tbl)["max_ratio"].as<int64_t>()->get()) };
  } else {
    throw std::runtime_error(
      std::format("Unknown policy type '{}' in {}", type_str, policy_name));
  }
}
