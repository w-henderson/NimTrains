![NimTrains banner](assets/banner.png)

# NimTrains

NimTrains is an extremely quick and simple command-line interface and Nim package to get realtime UK train information from [Worldline's "Tiger" train API](http://iris2.rail.co.uk/tiger/). It's a like-for-like Nim port of my Python project [PyTrains](https://github.com/w-henderson/PyTrains), but as you'll see when you read on, it has some huge advantages over its Python counterpart.

## Quick Start

Start by downloading a binary from [the releases page](https://github.com/w-henderson/NimTrains/releases) and adding it to your PATH so you have access to the `nimtrains` command from any command prompt.

### Departures
To view the departures from a station, you can run `nimtrains <station name or CRS code>`, for example `nimtrains BHM` or `nimtrains "birmingham new street"`. If the station name has any spaces in it, you'll need to put it in quotation marks.

### Individual Service Information
You'll notice that each service has an ID on the left. To see more information about a specific service from the station, run `nimtrains <station name or CRS code> [-i, --id] <service ID>`, for example `nimtrains PNZ -i 1` or `nimtrains penzance --id 3`.

### Next Train to a Destination
To get information about the next train to a certain destination, you can run `nimtrains <origin station> [-d, --dest] <destination station>`. For example, `nimtrains PAD -d BRI` or `nimtrains "london paddington" --dest "bristol temple meads"`.

## Comparison with [PyTrains](https://github.com/w-henderson/PyTrains)
You might've seen my other project, PyTrains, which provides an identical CLI to this one, written in Python. While these two projects both have the same functionality, it's easy to determine which you should use using this table:

| PyTrains | NimTrains |
| --- | --- |
| ✔️ Provides a **CLI** | ✔️ Provides a **CLI** |
| ✔️ Provides an **easy-to-use Python library** | ✔️ Provides an **easy-to-use Nim package** |
| ❌ Is relatively slow | ✔️ **Is 12x faster than PyTrains** (excluding request time) |
| ✔️ **Doesn't require a binary** and is therefore **smaller** | ❌ Requires a ~500KB binary to be installed |
| ❌ Requires Python (>100MB) and 6 dependencies | ✔️ **No dependencies**, works out-of-the-box |

In short, use PyTrains if you want access to the Python library to use in your own code, but if you're only looking for a CLI to access realtime UK train information, NimTrains' massive speed advantage makes it a better option.