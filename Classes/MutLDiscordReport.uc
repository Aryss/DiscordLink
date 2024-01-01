class MutLDiscordReport extends Mutator
    config;

var config string TKLFileName;


var bool bEnabled;
var bool bLinkEnabled;
var TKLMutatorTcpLinkClient TKLMTLC;

var string FileRecord; 

struct ReportMsg
{
    var string Payload;
};

var ReportMsg LogRecord;
var array<ReportMsg> RecordQueue;

final function FirstTimeConfig()
{
    if (Len(TKLFileName) == 0)
    {
        class'TKLMutatorTcpLinkClient'.static.StaticFirstTimeConfig();
    }
}

function PreBeginPlay()
{
    FirstTimeConfig();
    SaveConfig();

    log("[DiscordLink]: initializing TKLMutator, attempting to spawn TKLMutatorTcpLinkClient");
	TKLMTLC = Spawn(class'TKLMutatorTcpLinkClient');
    if (TKLMTLC == None){
		bLinkEnabled = False;
		log("[DiscordLink]: error spawning TKLMutatorTcpLinkClient");
        return;
    }
    TKLMTLC.Parent = self;
    bLinkEnabled = True;
    log("[DiscordLink]: TKLMutatorTcpLinkClient initialized");
	
    if (Level.Game.GameStatsClass == "LDiscordLink.LGameStats")
    	return;

    // Here goes an ugly hack for stupid function InitLogging in GameInfo:

    // If we're offline or it's a listen server we'll force the game
    // to spawn the logger
    if (Level.NetMode == NM_Standalone || Level.NetMode == NM_ListenServer)
      Level.Game.GameStats = spawn(class'LGameStats');

    // if it's a dedicated server this trick won't work - it'll crash the game
    // we'll just make the game load our class instead of default
    else if (Level.NetMode == NM_DedicatedServer)
      Level.Game.GameStatsClass = "LDiscordLink.LGameStats";   

    super.PreBeginPlay();
}



function PostBeginPlay()
{
    SetCancelOpenLinkTimer(2.0);
    super.PostBeginPlay();
	
}

function SendMSG(string data)
{
  LogRecord.Payload = data;
  
  RecordQueue.Length = RecordQueue.Length+1;
  RecordQueue[RecordQueue.Length-1] = LogRecord;
  Log("[DiscordLink] Added a text to processing queue: "$RecordQueue[RecordQueue.Length-1].Payload);
  Log("[DiscordLink] Processing queue length: "$RecordQueue.Length);
  ProcessQueue();
}



final function CloseLink()
{
    if (TKLMTLC != None)
    {
        bLinkEnabled = False;
        TKLMTLC.Close();
        TKLMTLC.Destroy();
    }
}

// Stupid hack to avoid TKLMTLC.Open() from spamming logs if it fails.
final function SetCancelOpenLinkTimer(float Time)
{
    SetTimer(Time, False);
}

final function CancelOpenLink()
{
    if (TKLMTLC != None && !TKLMTLC.IsConnected())
    {
        log("[DiscordLink]: cancelling link connection attempt");
        TKLMTLC.Close();
    }
}

final function CleanUp()
{
    bEnabled = False;
    CloseLink();
}

/*
Simulated Function Tick(Float TimeDelta)
{
    ProcessQueue();
    Disable('Tick');
}
*/

function Mutate(string MutateString, PlayerController Sender)
{
	if ( NextMutator != None )
		NextMutator.Mutate(MutateString, Sender);
		
	if (MutateString == "embed") 
		SendMSG("EMB__"$Rand(1000)$";Joe%Eric%Phil%;Smith%Ska'Hara%X9653%;31%26%7;20%7%6%;%1%0%0;%20%7%6");
}


final function ProcessQueue()
{
    local int NumProcessed;
	local int i;

    if (RecordQueue.Length == 0)
    {
        return;
		log("ProcessQueue(): MSG Queue length is zero, aborting");
    }

    for (i = 0; i < RecordQueue.Length; i++){
        FileRecord = RecordQueue[i].Payload;

        if (bLinkEnabled && TKLMTLC != None)
        {
            // NetRecord = Compress(Record);
            TKLMTLC.SendBufferedData(FileRecord);
			log("[DiscordLink] ProcessQueue(), sending data :"$FileRecord);
        }
		else {
			log("[DiscordLink] ProcessQueue(): Not sending the message because link wasn't set up");		
		}
        NumProcessed++;
    }

    RecordQueue.Remove(0, NumProcessed);
}

event Destroyed()
{
    // log("[TKLMutator]: Destroyed()");
    CleanUp();
    super.Destroyed();
}

defaultproperties
{
   FriendlyName="Discord Reporter" 
}
