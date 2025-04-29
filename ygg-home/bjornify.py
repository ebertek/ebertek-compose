#!/usr/bin/python
"""Load Björnify Discord.py bot"""

import logging
import os
import discord
import soco
import spotipy
from discord.ext import commands
from spotipy.oauth2 import SpotifyOAuth

# Set up logging
logging.basicConfig(
    filename="logs/bjornify.log",
    filemode="w",
    format="%(asctime)s | %(levelname)-8s | %(name)-20s | %(message)s",
    datefmt="%Y-%m-%d - %H:%M:%S",
    level=logging.INFO,
    encoding="utf-8",
)

_LOGGER = logging.getLogger(__name__)
_LOGGER.setLevel(logging.DEBUG)
logging.getLogger().setLevel(logging.INFO)
logging.getLogger("discord").setLevel(logging.INFO)
logging.getLogger("spotipy").setLevel(logging.INFO)
logging.getLogger("soco").setLevel(logging.INFO)

# Load environment variables
SPOTIPY_CLIENT_ID = os.getenv("SPOTIPY_CLIENT_ID")
SPOTIPY_CLIENT_SECRET = os.getenv("SPOTIPY_CLIENT_SECRET")
SPOTIPY_REDIRECT_URI = os.getenv("SPOTIPY_REDIRECT_URI")
DISCORD_BOT_TOKEN = os.getenv("DISCORD_BOT_TOKEN")
CHANNEL_ID = os.getenv("CHANNEL_ID")

# Validate that all required env vars are set
required_env_vars = [
    "SPOTIPY_CLIENT_ID",
    "SPOTIPY_CLIENT_SECRET",
    "SPOTIPY_REDIRECT_URI",
    "DISCORD_BOT_TOKEN",
    "CHANNEL_ID",
]

for var in required_env_vars:
    if not os.getenv(var):
        raise EnvironmentError(f"Missing required environment variable: {var}")

# Set up Spotify
SCOPE = (
    "user-library-read"
    ",user-read-currently-playing"
    ",user-read-playback-state"
    ",user-modify-playback-state"
)

auth_manager = SpotifyOAuth(
    client_id=SPOTIPY_CLIENT_ID,
    client_secret=SPOTIPY_CLIENT_SECRET,
    redirect_uri=SPOTIPY_REDIRECT_URI,
    scope=SCOPE,
    open_browser=False
)
spotify = spotipy.Spotify(auth_manager=auth_manager)

# Set up Discord
intents = discord.Intents.default()
intents.members = True
intents.messages = True
intents.message_content = True
bot = commands.Bot(
    command_prefix="!",
    description="Björnify adds requested tracks to Björngrottan's Spotify playback queue",
    intents=intents,
)


def refresh_spotify_token():
    """Force refresh Spotify access token."""
    global spotify  # pylint: disable=W0603
    _LOGGER.info("Refreshing Spotify access token manually.")

    auth_manager.refresh_access_token(auth_manager.get_cached_token()["refresh_token"])
    spotify = spotipy.Spotify(auth_manager=auth_manager)


def find_playing_speaker():
    """Find and return the currently playing Sonos speaker using SoCo."""
    speakers = soco.discover()

    if not speakers:
        _LOGGER.info("No Sonos speakers found.")
        return None

    checked_coordinators = set()

    for speaker in speakers:
        coordinator = speaker.group.coordinator

        if coordinator.uid in checked_coordinators:
            continue

        checked_coordinators.add(coordinator.uid)

        state = coordinator.get_current_transport_info()["current_transport_state"]
        if state == "PLAYING":
            _LOGGER.info(
                "Currently playing coordinator: %s (%s)",
                coordinator.player_name,
                coordinator.ip_address,
            )
            members_info = "\n".join(
                f" - {member.player_name} ({member.ip_address})"
                for member in coordinator.group.members
            )
            _LOGGER.info("Group members:\n%s", members_info)

            return coordinator  # Return the playing coordinator speaker

    _LOGGER.info("No Sonos speakers are currently playing.")
    return None


def spotify_action_with_soco_fallback(spotify_action, soco_action, action_name):
    """Try a Spotify action, fallback to a SoCo action if Spotify fails with 403."""
    # GET /me/player
    playback_results = spotify.current_playback()
    if playback_results is not None:
        try:
            # POST /me/player/next or PUT /me/player/pause
            spotify_action()
            _LOGGER.debug("%s via Spotify", action_name)
            return "✅"
        except spotipy.exceptions.SpotifyException as e:
            if e.http_status == 401:
                _LOGGER.warning("Spotify token expired, refreshing token.")
                refresh_spotify_token()
                try:
                    spotify_action()  # Retry once after refreshing
                    _LOGGER.debug("%s via Spotify (after refresh)", action_name)
                    return "✅"
                except Exception as ex:  # pylint: disable=W0718
                    _LOGGER.error("Failed after token refresh: %s", ex)
                    return "🚫"
            if e.http_status == 403:
                _LOGGER.warning(
                    "Spotify refused to %s: Restricted device. Trying with SoCo.",
                    action_name
                )
                playing_speaker = find_playing_speaker()
                if playing_speaker:
                    try:
                        soco_action(playing_speaker)
                        _LOGGER.info(
                            "%s using SoCo: %s",
                            action_name.capitalize(),
                            playing_speaker.player_name
                        )
                        return "✅"
                    except Exception as ex:  # pylint: disable=W0718
                        _LOGGER.error("Failed to %s via SoCo: %s", action_name, ex)
                        return "🚫"
                _LOGGER.warning("No active speaker found via SoCo.")
                return "🚫"
            _LOGGER.error("Unexpected Spotify error during %s: %s", action_name, e)
            return "🚫"
    _LOGGER.debug("%s failed: no playback found.", action_name.capitalize())
    return "🚫"


@bot.event
async def on_ready():
    """Bot logged in"""
    _LOGGER.info("Logged in as %s", bot.user)


@bot.event
async def on_message(message):
    """New message"""
    _LOGGER.debug("New message in %s", message.channel.id)
    # Ignore the bot's own messages
    if message.author == bot.user or message.author.bot:
        _LOGGER.debug("Message ignored from %s", message.author)
        return

    # Check if the message is in the correct channel
    _LOGGER.debug("Check if it matches %s", CHANNEL_ID)
    if int(message.channel.id) == int(CHANNEL_ID):
        _LOGGER.debug("Channel matches")
        query = message.content
        _LOGGER.debug("Query: %s", query)
        if query.startswith("!add "):
            response = player_add_item_to_playback_queue(query.removeprefix("!add "))
            await message.channel.send(response)
        elif query.startswith("!next"):
            response = await bot.loop.run_in_executor(None, player_skip_to_next)
            await message.add_reaction(response)
        elif query.startswith("!pause") or query.startswith("!stop"):
            response = await bot.loop.run_in_executor(None, player_pause_playback)
            await message.add_reaction(response)


def player_add_item_to_playback_queue(query):
    """Add the track to the playback queue if there are any search results"""
    try:
        # Get the top result for the query: GET tracks.items[0].uri
        search_results = spotify.search(q=query, limit=1, type="track")
        search_items = search_results["tracks"]["items"]

        if len(search_items) > 0:
            artist = search_items[0]["artists"][0]["name"]
            name = search_items[0]["name"]
            uri = search_items[0]["uri"]
            _LOGGER.debug("Artist: %s, name: %s, uri: %s", artist, name, uri)

            # GET /me/player
            playback_results = spotify.current_playback()
            if playback_results is not None:
                # POST /me/player/queue
                spotify.add_to_queue(uri)
                _LOGGER.debug("Queued: %s - %s", artist, name)
                return f"Queued: {artist} - {name}"

            # GET /me/player/devices
            devices = spotify.devices()
            device_id = None
            for device in devices["devices"]:
                if device["name"] == "Everywhere":
                    device_id = device["id"]
                    break
            if device_id is None and devices["devices"]:
                device_id = devices["devices"][0]["id"]
            if device_id:
                _LOGGER.debug("device_id: %s", device_id)
                # PUT /me/player/play
                spotify.start_playback(
                    device_id=device_id,
                    uris=[uri]
                )
                _LOGGER.debug("Started playback: %s - %s", artist, name)
                return f"Started playback: {artist} - {name}"
            _LOGGER.warning("No available devices to start playback.")

        return "No results"
    except spotipy.exceptions.SpotifyException as e:
        _LOGGER.error("Spotify error during add to queue: %s", e)
        return "Failed to add track to queue."
    except Exception as e:  # pylint: disable=W0718
        _LOGGER.error("Unexpected error during add to queue: %s", e)
        return "Failed to add track to queue."


def player_skip_to_next():
    """Skip to next track"""
    return spotify_action_with_soco_fallback(
        spotify_action=spotify.next_track,
        soco_action=lambda speaker: speaker.next(),
        action_name="skip to next track"
    )


def player_pause_playback():
    """Pause playback"""
    return spotify_action_with_soco_fallback(
        spotify_action=spotify.pause_playback,
        soco_action=lambda speaker: speaker.pause(),
        action_name="pause playback"
    )


# Run the bot
bot.run(DISCORD_BOT_TOKEN)
