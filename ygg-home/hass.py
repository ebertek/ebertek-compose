#!/usr/bin/env python
"""Load hass Discord.py bot"""
# Based on:
#  https://www.reddit.com/r/homeassistant/comments/1fcjypt/discord_assist_via_conversation_api/
import logging
import os
import discord
import requests
from discord.ext import commands

# Set up logging
logging.basicConfig(
    filename="logs/hass.log",
    filemode="w",
    format="%(asctime)s | %(levelname)-8s | %(name)-20s | %(message)s",
    datefmt="%Y-%m-%d - %H:%M:%S",
    level=logging.INFO,
    encoding="utf-8",
)

# Load environment variables
DISCORD_BOT_TOKEN = os.getenv("HASS_DISCORD_BOT_TOKEN")
CHANNEL_ID = os.getenv("HASS_CHANNEL_ID")
HA_URL = os.getenv("HA_URL")
HA_ACCESS_TOKEN = os.getenv("HA_ACCESS_TOKEN")

# Validate that all required env vars are set
required_env_vars = [
    "HASS_DISCORD_BOT_TOKEN",
    "HASS_CHANNEL_ID",
    "HA_URL",
    "HA_ACCESS_TOKEN",
]

for var in required_env_vars:
    if not os.getenv(var):
        raise EnvironmentError(f"Missing required environment variable: {var}")

# Set up Bot
intents = discord.Intents.default()
intents.members = True
intents.messages = True
intents.message_content = True
bot = commands.Bot(
    command_prefix="!",
    description="Control Home Assistant in Björngrottan",
    intents=intents,
)


@bot.event
async def on_ready():
    """Bot logged in"""
    logging.info("Logged in as %s", bot.user)


@bot.event
async def on_message(message):
    """New message"""
    logging.debug("New message in %s", message.channel.id)
    # Ignore the bot's own messages
    if message.author == bot.user or message.author.bot:
        logging.debug("Message ignored from %s", message.author)
        return

    # Check if the message is in the specified channel
    logging.debug("Check if it matches %s", CHANNEL_ID)
    if int(message.channel.id) == int(CHANNEL_ID):
        logging.debug("Channel matches")
        query = message.content
        logging.debug("Query: %s", query)
        response = send_query_to_ha_assist(query)  # Send the query to HA Assist
        await message.channel.send(response)  # Respond in the same channel


def send_query_to_ha_assist(query):
    """Prepare the API request to Home Assistant Assist"""
    url = HA_URL
    headers = {
        "Authorization": f"Bearer {HA_ACCESS_TOKEN}",
        "Content-Type": "application/json",
    }
    data = {"text": query, "language": "en"}

    # Send the request to HA Assist and handle the response
    response = requests.post(url, json=data, headers=headers, timeout=30)

    if response.status_code == 200:
        logging.debug("Response: %s", str(response.json()))
        return response.json()["response"]["speech"]["plain"][
            "speech"
        ]  # Extract the response text

    logging.info("Error communicating with Home Assistant.")
    return "Error communicating with Home Assistant."


# Run the bot
bot.run(DISCORD_BOT_TOKEN)
