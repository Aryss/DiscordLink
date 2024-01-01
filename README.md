# DiscordLink


This mutator provides real time reporting of match events from UT2004 server to a specific channel in a Discord server via webhooks. This work is based on [tuokri](https://github.com/tuokri)'s [rs2-tklogging](https://github.com/tuokri/rs2-tklogging) and [tklserver](https://github.com/tuokri/tklserver) code. Since UT2004 doesn't know SSL and Discord is all SSL, DiscordLink requires an interim Python server that listens to the events sent from UT, processes them a bit and wraps them in a webhook call.

### Examples

![Screenshot 2024-01-01 173625](https://github.com/Aryss/DiscordLink/assets/7546239/d5c13be5-5c71-40c9-8fb9-984c8136b27a) ![Screenshot 2024-01-01 175103](https://github.com/Aryss/DiscordLink/assets/7546239/6d5a1212-7437-440a-a9b2-aa5f227077e0)
![Screenshot 2024-01-01 175130](https://github.com/Aryss/DiscordLink/assets/7546239/d6586d56-b7f5-44a4-ae7b-1e7ee8d0dd2f) ![Screenshot 2024-01-01 175204](https://github.com/Aryss/DiscordLink/assets/7546239/71136e63-0d1b-4fbf-951e-4d1988245543)




Main UT2004 code is based on UT's own built-in stats and I repurposed quite a bit of code from my old GameLogger mutator that I wrote ~17-19 years ago or so. It does some preliminary sorting and processing that can be easily done in UnrealScript and which requires game logic or configuration through webadmin. The stripped down data (I want to keep it as short as possible as the existing implementation of BufferedTCPLink is limited to a buffer of 2048 bytes and that's a hard limit imposed by UE2) – is sent to the Python server which creates an embed and does some additional string processing of the data.

Currently while I'm still working on this, I'm only providing a basic guide on how to set this up. A proper guide on how to set this up will be available later. Requests and questions can be asked in this Discord server: https://discord.gg/5YTkVvdkhG

Setup steps: 

0. First and foremost to run this you need to be able to run a python3 script alongside your server or on a separate box. This is where you run the server script from the PyServer folder. 
1. Create a webhook in a channel you want the reports to be sent to and update the tklserver.ini with the webhook link and the server info.
2. Run the python server, the console will say it's started and listening
3. Add the following entries to the end of your server config (proper WebAdmin support coming, but doesn't quite work for now):

```
[LDiscordLink.TKLMutatorTcpLinkClient]
TKLServerHost=[your Py server IP]
TKLServerPort=[your Py server port]
MaxRetries=5

[LDiscordLink.LGameStats]
bOLStatsEnabled=False
bFlavorHeading=True
bReportMatchStart=True
bReportScoreEvents=True
bPostCapSummary=True```

4. Start a server with LDiscordLink.MutLDiscordReport/Discord Link mutator. You should see a connection appear in Python server log.

Important info about config values: 

- **TKLServerHost** - the IP of your Python server. Use localhost if it's running on the same machine
- **TKLServerPort** - Port used by the Python server.

- **bOLStatsEnabled** - by default, UT2004 only allows a single stats class. If you enable this and have OLStats installed, this will attempt to spawn OLStats's own logger and pass through all stats events letting it create a tradional log 
- **bFlavorHeading** - adds a "flavor" text to CTF match summaries based on the score. Current headings are still WIP. 
- **bReportScoreEvents** - this will send event whenever a team scores (outside of TDM or DOM) or completes an objective in AS 
- **bPostCapSummary** - this will add a summary of the captures to the post-match summary of a CTF/BR games




