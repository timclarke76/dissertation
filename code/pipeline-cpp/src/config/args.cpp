#include "args.h"

Args::Args(const int argc, const char* const* argv)
{
  argparse::ArgumentParser parser(argv[0]);

  parser.add_argument("-s", "--settings")
    .help("The name of the settings file")
    .default_value(std::string("settings.toml"));

  parser.parse_args(argc, argv);
  settings_ = parser.get<std::string>("--settings");
}
