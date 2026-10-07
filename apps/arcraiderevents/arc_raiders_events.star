"""
Applet: ARC Raid Events
Summary: ARC Raiders event timers
Description: Displays active and upcoming ARC Raiders in-game events with live countdown timers. Features official brand colors, logo-stripe accents, scrolling event names, and map locations. Filter by map and server region with the configurable dropdowns. Data sourced from MetaForge.app.
Author: jeffver
:)
"""

load("cache.star", "cache")
load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

API_URL = "https://metaforge.app/api/arc-raiders/events-schedule"
CACHE_TTL = 300  # 5 minutes

# Server region. Map conditions run on per-region schedules since patch 1.42.0.
# MetaForge defaults to "europe" when no region is sent.
# VERIFY this value: check the events-schedule request in browser DevTools on
# metaforge.app/arc-raiders/event-timers with North America selected.
DEFAULT_REGION = "north-america"
REGION_PARAM = "region"

# ARC Raiders brand colors (from logo stripes)
ARC_CYAN = "#00e5ff"  # Leftmost stripe
ARC_GREEN = "#00e050"  # Second stripe
ARC_YELLOW = "#ffd600"  # Third stripe
ARC_RED = "#ff3030"  # Rightmost stripe

# Dimmed variants for secondary text
ARC_CYAN_DIM = "#006670"
ARC_GREEN_DIM = "#005820"
ARC_YELLOW_DIM = "#665500"
ARC_RED_DIM = "#661414"

# Neutrals
WHITE = "#ffffff"
GRAY = "#9ca3af"
DARK_GRAY = "#374151"
BG_DARK = "#0a0a0f"

# Map short names to fit on 64px display
MAP_SHORT = {
    "Dam": "DAM",
    "Spaceport": "SPCE",
    "Buried City": "BCTY",
    "Blue Gate": "BGAT",
    "Stella Montis": "SMON",
    "Riven Tides": "RTID",
}

# Event short names
EVENT_SHORT = {
    "Close Scrutiny": "CLOSE SCRUT",
    "Night Raid": "NIGHT RAID",
    "Electromagnetic Storm": "EM STORM",
    "Husk Graveyard": "HUSK GRAVE",
    "Bird City": "BIRD CITY",
    "Harvester": "HARVESTER",
    "Matriarch": "MATRIARCH",
    "Hurricane": "HURRICANE",
    "Hidden Bunker": "HID BUNKER",
    "Locked Gate": "LOCKED GATE",
    "Launch Tower Loot": "TOWER LOOT",
    "Prospecting Probes": "PROBES",
    "Uncovered Caches": "CACHES",
    "Lush Blooms": "LUSH BLOOM",
    "Beachcombing": "BEACHCOMB",
}

def get_short_map(map_name):
    return MAP_SHORT.get(map_name, map_name[:4].upper())

def get_short_event(event_name):
    return EVENT_SHORT.get(event_name, event_name[:12].upper())

def pad_zero(n):
    """Pad a number with a leading zero if less than 10."""
    if n < 10:
        return "0" + str(int(n))
    return str(int(n))

def format_countdown(ms_remaining):
    """Format milliseconds remaining into a readable countdown."""
    if ms_remaining <= 0:
        return "NOW"
    total_seconds = int(ms_remaining / 1000)
    hours = int(total_seconds / 3600)
    minutes = int((total_seconds % 3600) / 60)
    seconds = total_seconds % 60
    if hours > 0:
        return str(hours) + ":" + pad_zero(minutes) + ":" + pad_zero(seconds)
    elif minutes > 0:
        return pad_zero(minutes) + ":" + pad_zero(seconds)
    else:
        return "0:" + pad_zero(seconds)

def truncate_name(name, max_chars):
    """Truncate name to fit display width."""
    if len(name) > max_chars:
        return name[:max_chars] + ".."
    return name

def error_screen(message):
    return render.Root(
        child = render.Box(
            render.Column(
                cross_align = "center",
                main_align = "center",
                children = [
                    render.Text("ARC RAIDERS", color = ARC_RED, font = "tom-thumb"),
                    render.Box(width = 64, height = 1, color = DARK_GRAY),
                    render.Text(message, color = ARC_YELLOW, font = "tom-thumb"),
                ],
            ),
        ),
    )

def fetch_events(region):
    """Fetch the event schedule for a region, with per-region caching."""
    cache_key = "arc_events_" + region
    cached = cache.get(cache_key)
    if cached != None:
        return json.decode(cached)

    rep = http.get(API_URL, params = {REGION_PARAM: region})
    if rep.status_code != 200:
        return None

    body = rep.json()
    events = body
    if type(body) == "dict":
        got = body.get("region")
        if got and got != region:
            print("arc_raiders_events: region mismatch, asked %s, got %s" % (region, got))
        events = body.get("data", [])

    cache.set(cache_key, json.encode(events), ttl_seconds = CACHE_TTL)
    return events

def main(config):
    # Get current time in milliseconds
    now = time.now()
    now_ms = now.unix_nano // 1000000

    # Config
    map_filter = config.get("map_filter", "All")
    region = config.get("region", DEFAULT_REGION)

    events = fetch_events(region)
    if events == None:
        return error_screen("API ERROR")

    # Filter by map if specified
    if map_filter != "All":
        events = [e for e in events if e["map"] == map_filter]

    # Separate into active and upcoming events
    active_events = []
    upcoming_events = []
    for event in events:
        start = int(event["startTime"])
        end = int(event["endTime"])
        if start <= now_ms and now_ms < end:
            active_events.append(event)
        elif start > now_ms and len(upcoming_events) < 6:
            upcoming_events.append(event)

    # Build event list for display
    display_events = []
    for event in active_events[:3]:
        display_events.append({
            "name": event["name"],
            "map": event["map"],
            "remaining_ms": int(event["endTime"]) - now_ms,
            "type": "active",
        })

    # Fallback if no events
    if len(display_events) == 0:
        return render.Root(
            child = render.Box(
                color = BG_DARK,
                child = render.Column(
                    cross_align = "center",
                    main_align = "center",
                    expanded = True,
                    children = [
                        render.Text("ARC RAIDERS", color = ARC_CYAN, font = "tom-thumb"),
                        render.Box(width = 64, height = 2),
                        render.Text("NO EVENTS", color = GRAY, font = "tom-thumb"),
                        render.Text("SCHEDULED", color = GRAY, font = "tom-thumb"),
                    ],
                ),
            ),
        )

    # Generate animated frames with live countdown
    # Each event shown for ~4 seconds, countdown ticks every second
    animation_frames = []
    seconds_per_event = 4
    frames_per_second = 10  # 10fps
    global_sec = 0

    for evt in display_events:
        for _ in range(seconds_per_event):
            remaining = evt["remaining_ms"] - (global_sec * 1000)
            if remaining < 0:
                remaining = 0
            countdown = format_countdown(remaining)
            global_sec = global_sec + 1

            if evt["type"] == "active":
                status_label = "ARC Raiders"
                status_color = WHITE
                timer_color = ARC_GREEN
                suffix = countdown
                suffix_color = ARC_RED
                name_color = ARC_YELLOW
            else:
                status_label = "UPCOMING"
                status_color = ARC_CYAN
                timer_color = ARC_CYAN
                suffix = countdown
                suffix_color = ARC_CYAN
                name_color = WHITE

            # Determine right-side content: logo stripes for active, countdown for upcoming
            if evt["type"] == "active":
                right_side = render.Row(
                    children = [
                        render.Box(width = 1, height = 5, color = ARC_CYAN),
                        render.Box(width = 1, height = 5, color = ARC_GREEN),
                        render.Box(width = 1, height = 5, color = ARC_YELLOW),
                        render.Box(width = 1, height = 5, color = ARC_RED),
                    ],
                )
            else:
                right_side = render.Text(countdown, color = timer_color, font = "tom-thumb")

            frame = render.Box(
                color = BG_DARK,
                child = render.Padding(
                    pad = (0, 0, 0, 0),
                    child = render.Column(
                        expanded = True,
                        main_align = "space_between",
                        children = [
                            render.Row(
                                expanded = True,
                                main_align = "center",
                                cross_align = "center",
                                children = [
                                    render.Row(
                                        children = [
                                            render.Box(width = 1, height = 5, color = ARC_CYAN),
                                            render.Box(width = 1, height = 5, color = ARC_GREEN),
                                            render.Box(width = 1, height = 5, color = ARC_YELLOW),
                                            render.Box(width = 1, height = 5, color = ARC_RED),
                                        ],
                                    ),
                                    render.Box(width = 1, height = 1),
                                    render.Text(status_label, color = status_color, font = "tom-thumb"),
                                    render.Box(width = 1, height = 1),
                                    right_side,
                                ],
                            ),
                            render.Column(
                                cross_align = "center",
                                children = [
                                    render.Box(width = 64, height = 1, color = "#007380"),
                                    render.Box(width = 64, height = 1, color = "#007028"),
                                    render.Text(truncate_name(evt["name"], 15), color = name_color, font = "tom-thumb"),
                                    render.Box(width = 64, height = 1, color = "#806b00"),
                                    render.Box(width = 64, height = 1, color = "#801818"),
                                ],
                            ),
                            render.Stack(
                                children = [
                                    render.Row(
                                        expanded = True,
                                        main_align = "start",
                                        children = [
                                            render.Text(evt["map"], color = ARC_CYAN, font = "CG-pixel-3x5-mono"),
                                        ],
                                    ),
                                    render.Row(
                                        expanded = True,
                                        main_align = "end",
                                        children = [
                                            render.Text(suffix, color = suffix_color, font = "tom-thumb"),
                                        ],
                                    ),
                                ],
                            ),
                        ],
                    ),
                ),
            )

            # Repeat this frame for 1 second of display time
            for _ in range(frames_per_second):
                animation_frames.append(frame)

    return render.Root(
        delay = 100,
        child = render.Animation(
            children = animation_frames,
        ),
    )

def get_schema():
    # Region values other than the default are unverified guesses in the same
    # slug style; adjust to match what the MetaForge API actually accepts.
    regions = [
        schema.Option(display = "North America", value = "north-america"),
        schema.Option(display = "Europe", value = "europe"),
        schema.Option(display = "South America", value = "south-america"),
        schema.Option(display = "Asia", value = "asia"),
        schema.Option(display = "Oceania", value = "oceania"),
    ]

    maps = [
        schema.Option(display = "All Maps", value = "All"),
        schema.Option(display = "Dam", value = "Dam"),
        schema.Option(display = "Spaceport", value = "Spaceport"),
        schema.Option(display = "Buried City", value = "Buried City"),
        schema.Option(display = "Blue Gate", value = "Blue Gate"),
        schema.Option(display = "Stella Montis", value = "Stella Montis"),
        schema.Option(display = "Riven Tides", value = "Riven Tides"),
    ]

    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "region",
                name = "Server Region",
                desc = "Event schedule for your server region",
                icon = "globe",
                default = DEFAULT_REGION,
                options = regions,
            ),
            schema.Dropdown(
                id = "map_filter",
                name = "Map Filter",
                desc = "Filter events by map",
                icon = "map",
                default = "All",
                options = maps,
            ),
        ],
    )
