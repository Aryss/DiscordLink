import base64
import io
import re
import socket
import sys
import threading
from datetime import datetime
from collections import defaultdict
from configparser import ConfigParser
from pathlib import Path
from socketserver import StreamRequestHandler
from socketserver import ThreadingTCPServer
from typing import Optional
from typing import Tuple

import discord
import logbook
import requests
from PIL import Image
from discord import SyncWebhook
from logbook import Logger
from logbook.handlers import RotatingFileHandler
from logbook.handlers import StreamHandler




StreamHandler(
    sys.stdout, level="INFO", bubble=True).push_application()
RotatingFileHandler(
    "tklserver.log", level="INFO", bubble=True).push_application()
logger = Logger("tklserver")
logbook.set_datetime_format("local")


DATE_FMT = "%Y/%m/%d - %H:%M:%S"


class TKLServer(ThreadingTCPServer):
    daemon_threads = True

    def __init__(self, *args, stop_event: threading.Event,
#                 discord_config: dict, image_cache: Optional[ImageCache] = None,
                discord_config: dict,
                 **kwargs):
        super().__init__(*args, **kwargs)
        self._stop_event = stop_event
        self._discord_config = discord_config
#        self.image_cache = image_cache

    @property
    def stop_requested(self) -> bool:
        return self._stop_event.is_set()

    @property
    def discord_config(self) -> dict:
        return self._discord_config
'''
    def get_kill_icon(self, damage_type: str):
        try:
            return self.image_cache[damage_type]
        except KeyError:
            return None
'''

class TKLRequestHandler(StreamRequestHandler):

	
    def __init__(self, request, client_address, server: TKLServer, ):
        self.server: TKLServer = server
        self.lastSentScoreMsg = "0"
        self.lastSentSummaryMsg = "0"
        self.lastData = ""
        super().__init__(request, client_address, server)
		

    def match_start(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')
		
        if self.lastSentSummaryMsg == match_data[0]:
            return
		
        logger.info("Match start data:"+ msg)
        self.lastSentSummaryMsg = match_data[0]
        try:
            embed = discord.Embed(title="Match has started", description=match_data[3] + " on " + match_data[4], color=0x00c632, timestamp=datetime.now())
            embed.add_field(name="Goal Score", value=match_data[1], inline=True)
            embed.add_field(name="Time Limit", value=match_data[2] + "m", inline=True)			
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def as_match_start(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, round time, reinforcement delay, pais of rounds, map name
        match_data =  msg.split(';')
		
        if self.lastSentSummaryMsg == match_data[0]:
            return
		
        logger.info("Match start data: "+ msg)
        self.lastSentSummaryMsg = match_data[0]
				
        try:
            embed = discord.Embed(title="Match has started", description="Assaault on " + match_data[4], color=0x00c632, timestamp=datetime.now())
            embed.add_field(name="Round Time Limit", value=match_data[1] + "m", inline=True)
            embed.add_field(name="Reinforcements Time", value=match_data[2], inline=True)
            embed.add_field(name="Pairs of Rounds", value=match_data[3], inline=True)
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)
			
    def ctf_cap(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')
		
        if self.lastSentScoreMsg == match_data[0]:
            return
			
        logger.info("CTF cap: "+ msg)			
        tcolor = 0xea5353
        self.lastSentScoreMsg = match_data[0]
        try:
            if match_data[5] == "1":
                tcolor = 0x5164ec
            else:
                tcolor = 0xea5353
            embed = discord.Embed(title=match_data[4] + " captures the flag!", description=match_data[3] + " scores for the "+ match_data[4] +"\n Time: "+match_data[0], color=tcolor)
            embed.add_field(name="Score", value=":red_square:  **" + match_data[1] + ":" + match_data[2] + "**  :blue_square:", inline=True)
            '''embed.add_field(name="Red Team", value=match_data[1], inline=True)
            embed.add_field(name="Blue Team", value=match_data[2], inline=True)'''
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def br_tcd(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')

		
        if self.lastSentScoreMsg == match_data[0]:
            return
			
        logger.info("BR cap: "+ msg)		
        tcolor = 0xea5353
        self.lastSentScoreMsg = match_data[0]
        try:
            if match_data[5] == "1":
                tcolor = 0x5164ec
            else:
                tcolor = 0xea5353
            embed = discord.Embed(description="**" + match_data[0] + ":** " + match_data[3] + " makes a touchdown for the "+ match_data[4], color=tcolor)
            embed.add_field(name="Score", value=":red_square:  **" + match_data[1] + ":" + match_data[2] + "**  :blue_square:", inline=True)
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def br_tss(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')

		
        if self.lastSentScoreMsg == match_data[0]:
            return
			
        logger.info("BR cap: "+ msg)		
        tcolor = 0xea5353
        self.lastSentScoreMsg = match_data[0]
        try:
            if match_data[5] == "1":
                tcolor = 0x5164ec
            else:
                tcolor = 0xea5353
            embed = discord.Embed(description="**" + match_data[0] + ":** " + match_data[3] + " scores for the "+ match_data[4], color=tcolor)
            embed.add_field(name="Score", value=":red_square:  **" + match_data[1] + ":" + match_data[2] + "**  :blue_square:", inline=True)

            '''
            embed = discord.Embed(title=match_data[4] + " scores!", description=match_data[3] + " scores for the "+ match_data[4] +"\n Time: "+match_data[0], color=tcolor)
            embed.add_field(name="Red Team", value=match_data[1], inline=True)
            embed.add_field(name="Blue Team", value=match_data[2], inline=True)	'''
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def overtime(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')

		
        if self.lastSentScoreMsg == match_data[0]:
            return
			
        logger.info("OT: "+ msg)		
        tcolor = 0xea5353
        self.lastSentScoreMsg = match_data[0]
        try:
            embed = discord.Embed(description="OVERTIME!", color=tcolor)
            embed.add_field(name="Score", value=":red_square:  **" + match_data[1] + ":" + match_data[2] + "**  :blue_square:", inline=True)

            '''
            embed = discord.Embed(title=match_data[4] + " scores!", description=match_data[3] + " scores for the "+ match_data[4] +"\n Time: "+match_data[0], color=tcolor)
            embed.add_field(name="Red Team", value=match_data[1], inline=True)
            embed.add_field(name="Blue Team", value=match_data[2], inline=True)	'''
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def round_win(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')

		
        if self.lastSentScoreMsg == match_data[0]:
            return
			
        logger.info("Round victory: "+ msg)		
        tcolor = 0xea5353
        self.lastSentScoreMsg = match_data[0]
        try:
            if match_data[3] == "1":
                tcolor = 0x5164ec
            else:
                tcolor = 0xea5353
            embed = discord.Embed(description="**" + match_data[0] + ":** " + match_data[4] + " wins the round!", color=tcolor)
            embed.add_field(name="Score", value=":red_square:  **" + match_data[1] + ":" + match_data[2] + "**  :blue_square:", inline=True)
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def as_round_win(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')

		
        if self.lastSentScoreMsg == match_data[0]:
            return
			
        logger.info("AS Round victory: "+ msg)		
        tcolor = 0xea5353
        self.lastSentScoreMsg = match_data[0]
        try:
            if match_data[3] == "1":
                tcolor = 0x5164ec
            else:
                tcolor = 0xea5353
            embed = discord.Embed(title="Round set completed: " + match_data[4], color=tcolor)
            embed.add_field(name="Score", value=":red_square:  **" + match_data[1] + ":" + match_data[2] + "**  :blue_square:", inline=True)
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def ons_core_dest(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')

		
        if self.lastSentScoreMsg == match_data[0]:
            return
			
        logger.info("BR cap:"+ msg)		
        tcolor = 0xea5353
        self.lastSentScoreMsg = match_data[0]
        try:
            if match_data[3] == "1":
                tcolor = 0x5164ec
            else:
                tcolor = 0xea5353
            embed = discord.Embed(description="**" + match_data[0] + ":** " + match_data[4] + " destroys the enemy core!", color=tcolor)
            embed.add_field(name="Score", value=":red_square:  **" + match_data[1] + ":" + match_data[2] + "**  :blue_square:", inline=True)
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def as_obj(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
		
        if self.lastSentScoreMsg == msg:
            return

        match_data =  msg.split(';')			
        logger.info("AS Obj:"+ msg)			
        tcolor = 0xea5353
        self.lastSentScoreMsg = msg
        try:
            if match_data[3] == "1":
                tcolor = 0x5164ec
            else:
                tcolor = 0xea5353
#            embed = discord.Embed(title=match_data[2] + " completes the objective!", description="**" + match_data[0] + ":** \"" + match_data[4][1:] + "\" completed by "+ match_data[1], color=tcolor)
            embed = discord.Embed(title="", description="**" + match_data[0] + ":** \"" + match_data[4][1:] + "\" completed by "+ match_data[1], color=tcolor)
			

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def ctf_match_end(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')


        if self.lastSentSummaryMsg == match_data[0]:
            return

        logger.info("CTF Match End:"+ msg)
        BlueScorersList = match_data[8].split('%')
        BlueScorers = "\n".join(str(x) for x in BlueScorersList)
        RedScorersList = match_data[7].split('%')
        RedScorers = "\n".join(str(x) for x in RedScorersList)
        BlueScoresList = match_data[10].split('%')
        BlueScores = "\n".join(str(x) for x in BlueScoresList)
        RedScoresList = match_data[9].split('%')
        RedScores = "\n".join(str(x) for x in RedScoresList)
        BlueCapsList = match_data[12].split('%')
        BlueCaps = "\n".join(str(x) for x in BlueCapsList)
        RedCapsList = match_data[11].split('%')
        RedCaps = "\n".join(str(x) for x in RedCapsList)
		
        if len(match_data) == 15:
            SummaryList = match_data[14].split('%')
            Caps = "\n".join(str(x) for x in SummaryList)

        tcolor = 0xea5353
        self.lastSentSummaryMsg = match_data[0]
        try:
            if match_data[1] == "1":
                tcolor = 0x5164ec
            else:
                tcolor = 0xea5353		
            embed = discord.Embed(title=match_data[3], description=match_data[13] + "\nFinal score: :red_square:  **" + match_data[2] + "**  :blue_square:\n\nScoring attempts: \n**Red:** " + match_data[5] + "\n**Blue:** " + match_data[6] + "\n\nThree stars: "+ match_data[4] + "\n\n**Scorers:**\n" + Caps, color=tcolor, timestamp=datetime.now())
            embed.add_field(name="Red Team", value=RedScorers, inline=True)
            embed.add_field(name="Score", value=RedScores, inline=True)
            embed.add_field(name="Captures", value=RedCaps, inline=True)
            embed.add_field(name="Blue Team", value=BlueScorers, inline=True)			
            embed.add_field(name="Score", value=BlueScores, inline=True)			
            embed.add_field(name="Captures", value=BlueCaps, inline=True)		

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def as_match_end(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')

        if self.lastSentSummaryMsg == match_data[0]:
            return

        logger.info("AS Match End:"+ msg)
        BlueScorersList = match_data[5].split('%')
        BlueScorers = "\n".join(str(x) for x in BlueScorersList)
        RedScorersList = match_data[4].split('%')
        RedScorers = "\n".join(str(x) for x in RedScorersList)
        BlueScoresList = match_data[7].split('%')
        BlueScores = "\n".join(str(x) for x in BlueScoresList)
        RedScoresList = match_data[6].split('%')
        RedScores = "\n".join(str(x) for x in RedScoresList)
        BlueCapsList = match_data[9].split('%')
        BlueCaps = "\n".join(str(x) for x in BlueCapsList)
        RedCapsList = match_data[8].split('%')
        RedCaps = "\n".join(str(x) for x in RedCapsList)
		
        tcolor = 0xea5353
        self.lastSentSummaryMsg = match_data[0]
        try:
            if match_data[1] == "1":
                tcolor = 0x5164ec
            else:
                tcolor = 0xea5353		
            embed = discord.Embed(title=match_data[11], description=match_data[10] + "\nFinal score: :red_square:  **" + match_data[2] + "**  :blue_square:\n\nThree stars: "+ match_data[3], color=tcolor, timestamp=datetime.now())
            embed.add_field(name="Red Team", value=RedScorers, inline=True)
            embed.add_field(name="Score", value=RedScores, inline=True)
            embed.add_field(name="Efficiency", value=RedCaps, inline=True)
            embed.add_field(name="Blue Team", value=BlueScorers, inline=True)			
            embed.add_field(name="Score", value=BlueScores, inline=True)			
            embed.add_field(name="Efficiency", value=BlueCaps, inline=True)		

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)
			
    def br_match_end(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')


        if self.lastSentSummaryMsg == match_data[0]:
            return

        logger.info("BR Match End:"+ msg)
        BlueScorersList = match_data[5].split('%')
        BlueScorers = "\n".join(str(x) for x in BlueScorersList)
        RedScorersList = match_data[4].split('%')
        RedScorers = "\n".join(str(x) for x in RedScorersList)
        BlueScoresList = match_data[7].split('%')
        BlueScores = "\n".join(str(x) for x in BlueScoresList)
        RedScoresList = match_data[6].split('%')
        RedScores = "\n".join(str(x) for x in RedScoresList)
        BlueCapsList = match_data[9].split('%')
        BlueCaps = "\n".join(str(x) for x in BlueCapsList)
        RedCapsList = match_data[8].split('%')
        RedCaps = "\n".join(str(x) for x in RedCapsList)
		
        tcolor = 0xea5353
        self.lastSentSummaryMsg = match_data[0]
        try:
            if match_data[1] == "1":
                tcolor = 0x5164ec
                heading = "Blue team wins the match"
            else:
                tcolor = 0xea5353		
                heading = "Red team wins the match"	
            embed = discord.Embed(title=heading, description=match_data[10] + "\nFinal score: :red_square:  **" + match_data[2] + "**  :blue_square:\n\n" + "Three stars: "+ match_data[3], color=tcolor, timestamp=datetime.now())
            embed.add_field(name="Red Team", value=RedScorers, inline=True)
            embed.add_field(name="Score", value=RedScores, inline=True)
            embed.add_field(name="Captures", value=RedCaps, inline=True)
            embed.add_field(name="Blue Team", value=BlueScorers, inline=True)			
            embed.add_field(name="Score", value=BlueScores, inline=True)			
            embed.add_field(name="Captures", value=BlueCaps, inline=True)		

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def tdm_match_end(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')

        if self.lastSentSummaryMsg == match_data[0]:
            return

        logger.info("TDM Match End:"+ msg)
        BlueScorersList = match_data[4].split('%')
        BlueScorers = "\n".join(str(x) for x in BlueScorersList)
        RedScorersList = match_data[3].split('%')
        RedScorers = "\n".join(str(x) for x in RedScorersList)
        BlueScoresList = match_data[6].split('%')
        BlueScores = "\n".join(str(x) for x in BlueScoresList)
        RedScoresList = match_data[5].split('%')
        RedScores = "\n".join(str(x) for x in RedScoresList)
        BlueCapsList = match_data[8].split('%')
        BlueCaps = "\n".join(str(x) for x in BlueCapsList)
        RedCapsList = match_data[7].split('%')
        RedCaps = "\n".join(str(x) for x in RedCapsList)
		
        tcolor = 0xea5353
        self.lastSentSummaryMsg = match_data[0]
        try:
            if match_data[1] == "1":
                tcolor = 0x5164ec
                heading = "Blue team wins the match"
            else:
                tcolor = 0xea5353		
                heading = "Red team wins the match"
            embed = discord.Embed(title=heading, description=match_data[9], color=tcolor, timestamp=datetime.now())
            embed.add_field(name="Red Team", value=RedScorers, inline=True)
            embed.add_field(name="Frags", value=RedScores, inline=True)
            embed.add_field(name="Efficiency", value=RedCaps, inline=True)
            embed.add_field(name="Blue Team", value=BlueScorers, inline=True)			
            embed.add_field(name="Frags", value=BlueScores, inline=True)			
            embed.add_field(name="Efficiency", value=BlueCaps, inline=True)		

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)


    def dm_match_end(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')

        if self.lastSentSummaryMsg == match_data[0]:
            return

        logger.info("DM Match End:"+ msg)
        RedScorersList = match_data[2].split('%')
        RedScorers = "\n".join(str(x) for x in RedScorersList)
        RedScoresList = match_data[3].split('%')
        RedScores = "\n".join(str(x) for x in RedScoresList)
        RedCapsList = match_data[4].split('%')
        RedCaps = "\n".join(str(x) for x in RedCapsList)
		
        tcolor = 0x95a898
        self.lastSentSummaryMsg = match_data[0]
        try:
            embed = discord.Embed(title=match_data[1] + " wins the match", description=match_data[5], color=tcolor, timestamp=datetime.now())
            embed.add_field(name="Player", value=RedScorers, inline=True)
            embed.add_field(name="Frags", value=RedScores, inline=True)
            embed.add_field(name="Efficiency", value=RedCaps, inline=True)	

        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def embed_test(self, ident: str, msg: str):
        embed: Optional[discord.Embed] = None
		# level.timeseconds, goalscore, time limit, mode, map name
        match_data =  msg.split(';')
		
        BlueScorersList = match_data[2].split('%')
        BlueScorers = "\n".join(str(x) for x in BlueScorersList)
        RedScorersList = match_data[1].split('%')
        RedScorers = "\n".join(str(x) for x in RedScorersList)

		
        if self.lastSentSummaryMsg == match_data[0]:
            #logger.info("Same as previous, skipping")
            return

        logger.info(msg)		
        logger.info("EmbedTest:"+ msg)
        
        test = "\n20\n30\n50"

        tcolor = 0xea5353
        self.lastSentSummaryMsg = match_data[0]
        try:
            embed = discord.Embed(title="Embed Test", description=match_data[4], color=tcolor, timestamp=datetime.now())
            """
			embed.add_field(name="Red Team", value=RedScorers, inline=True)
            embed.add_field(name="Score", value=RedScorers, inline=True)
            embed.add_field(name="Captures", value=test, inline=True)
            embed.add_field(name="Blue Team", value=BlueScorers, inline=True)			
            embed.add_field(name="Score", value=BlueScorers, inline=True)			
            embed.add_field(name="Captures", value=test, inline=True)			
"""
        except Exception as e:
            logger.error("error creating embed message: {e}",
                         e=e, exc_info=True)

        webhook_id = self.server.discord_config[ident][0]
        webhook_token = self.server.discord_config[ident][1]
        webhook = SyncWebhook.partial(
            id=webhook_id, token=webhook_token
			)

        if embed is not None:
            logger.info("sending webhook embed for {i}", i=ident)
            try:
                webhook.send(embed=embed)
            except Exception as e:
                logger.error(e, exc_info=True)
        else:
            logger.info("Else sending webhook message for {i}", i=ident)
            webhook.send(content=msg)

    def handle(self):
        try:
            logger.info("connection opened from: {sender}",
                        sender=self.client_address)

            while not self.server.stop_requested:
                data = self.rfile.readline()
                if data.startswith(b"\x00") or not data:
                    logger.info(
                        "received quit request from {sender}, closing connection",
                        sender=self.client_address)
                    break

                logger.debug("raw data: {data}", data=data)

                data = str(data, encoding="latin-1").strip()
                '''if data == self.lastData:
                    logger.info("Old Data:"+ self.lastData)
                    logger.info("New Data:"+ data)
                    logger.info("Discarding")					
                    break;
					
                self.lastData = data;'''
                ident = data[:4]
                data = data[4:]
                logger.debug("{i}: {data}", i=ident, data=data)

                if ident in self.server.discord_config:
                    type = data[:5]
                    data = data[5:]
                    if type == 'MSTRT':
                        self.match_start(ident, data)
                    elif type == 'ASMST':
                        self.as_match_start(ident, data)
                    elif type == 'CTFFC':
                        self.ctf_cap(ident, data)
                    elif type == 'BRTCD':
                        self.br_tcd(ident, data)
                    elif type == 'BRTSS':
                        self.br_tss(ident, data)
                    elif type == 'ONSCD':
                        self.ons_core_dest(ident, data)
                    elif type == 'TGRND':
                        self.round_win(ident, data)
                    elif type == 'ASRDW':
                        self.as_round_win(ident, data)
                    elif type == 'GENOT':
                        self.overtime(ident, data)
                    elif type == 'CTFES':
                        self.ctf_match_end(ident, data)
                    elif type == 'ASMES':
                        self.as_match_end(ident, data)
                    elif type == 'BRMES':
                        self.br_match_end(ident, data)
                    elif type == 'TDMES':
                        self.tdm_match_end(ident, data)
                    elif type == 'DMMES':
                        self.dm_match_end(ident, data)						
                    elif type == 'EMB__':
                        self.embed_test(ident, data)						
                    elif type == 'ASEVT':
                        self.as_obj(ident, data)
                    else:
                        logger.info("Unknown event type: {type}", type=type)					
                else:
                    logger.error("server unique ID {i} not in Discord config", i=ident)

        except (ConnectionError, socket.error) as e:
            logger.error("{sender}: connection error: {e}",
                         sender=self.client_address, e=e)

        except Exception as e:
            logger.error("error when handling request from {addr}: {e}",
                         addr=self.client_address, e=e)
            logger.exception(e)


def parse_webhook_url(url: str) -> Tuple[int, str]:
    resp = requests.get(url).json()
    _id = int(resp["id"])
    token = resp["token"]
    return _id, token


def load_config() -> dict:
    cp = ConfigParser()
    cp.read("tklserver.ini")
    sections = cp.sections()

    ret = defaultdict(dict, cp)
    for section in sections:
        if section.startswith("rs2server"):
            ident = section.split(".")[1]
            url = cp[section].get("webhook_url")
            try:
                ret["discord"][ident] = parse_webhook_url(url)
            except Exception as e:
                logger.error("webhook URL failure for RS2 server ID={i}: {e}",
                             i=ident, e=e)

    return ret


def terminate(stop_event: threading.Event):
    stop_event.set()


def main():
    config = load_config()

    try:
        server_config = config["tklserver"]
        port = server_config.getint("port")
        host = server_config["host"]
        if not port:
            logger.error("port not set, exiting...")
            sys.exit(-1)
    except (ValueError, KeyError) as e:
        logger.debug("invalid config: {e}", e=e, exc_info=True)
        logger.error("invalid config, exiting...")
        sys.exit(-1)

    stop_event = threading.Event()
    addr = (host, port)
    server = None
    try:
        server = TKLServer(addr, TKLRequestHandler, stop_event=stop_event,
                           discord_config=config["discord"])
#                           image_cache=image_cache)
        logger.info("serving at: {host}:{port}", host=addr[0], port=addr[1])
        logger.info("press CTRL+C to shut down the server")
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("server stop requested")
    finally:
        if server:
            t = threading.Thread(target=terminate, args=(stop_event,))
            t.start()
            t.join()
            server.shutdown()
            server.server_close()

    logger.info("server shut down successfully")


if __name__ == "__main__":
    main()
