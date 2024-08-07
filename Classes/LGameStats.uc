// ============================================================================
//  Discord Link Main Report Module
//  Revision: v1.0
// ----------------------------------------------------------------------------
//  Game Stats Class that hooks events and digests them for sending to Discord webhook.
//  Loosely based on old GameLogger code
//-----------------------------------------------------------------------------
//  by Michael "_Lynx" Sokolkov � 2004-2023
// ============================================================================
class LGameStats extends GameStats config;

var globalconfig bool bOLStatsEnabled;          // If true, OLStats logger is spawned and events are passed through
var globalconfig bool bFlavorHeading;           // Use flavour headings in match end summary
var globalconfig bool bReportMatchStart;        // Post "Match started" message?
var globalconfig bool bReportScoreEvents;       // Report goals/captures?
var globalconfig bool bReportSpreesStreaks;     // Report big sprees and kill streaks?
var globalconfig bool bPostCapSummary;          // CTF/BR Only: post the list of captures/goals in match end summary?
var globalconfig bool bPostObjSummary;          // AS Only: post the list of objective times in match end summary?
var globalconfig bool bPostSummaryOnMapChange;  // Post match summary if match ends prematurely by map switch?
//var globalconfig bool bEnableDebugLog;        // this will create a separate Log file in Userlogs
var globalconfig int  Priv;					    // The privileges required to modify settings via WebAdmin
var globalconfig int  MCSMinTime;               // Minimum required match duration to post summary on map change
var globalconfig int  MCSMinPlayers;            // Minimum required number of players in the game to post summary on map change


var bool bWasOvertime;
var bool bUTCompIsPresent;
var bool bUTCompWarmUpStarted;
var bool bMatchStarted;
var bool bFirstObjCompleted;
var float MatchStartTime;


var int RedScore;
var int BlueScore;

var GameStats OLSLogger;
var MutLDiscordReport DRP;
var teamInfo Winners;
var ASGameReplicationInfo ASGRI;

var localized array<string> NameString, DescString;


//=============================================================================
// Variables for the End of Match Summary, mostly CTF/DB
//
//=============================================================================


var bool bFirstScore;           // used to find if there were any captures before
var bool bOvertime;             // If the game went in overtime?


// ============================================================================
// AS Objectives struct
//
// local list of objectives used to iterate and build ordered objective summary
// ============================================================================
struct ASObjective{
  var string ObjDescription;
  var string    RedTime;
  var string    BlueTime;
};

var array<ASObjective> ASObjectives;

// ============================================================================
// team struct
//
// holds information on how well team plays this match. Switches are keeping
// information on score changes and being updated with each capture
// ============================================================================
struct teams{
  var TeamInfo thisTeam;             // Team Info of team to which these switches are related

  var bool bLostlead;                // team had lead, but lost it
  var bool brestoredlead;            // team had the lead, opponent tied, but team went ahead again
  var bool bReturnedlead;            // team was ahead, went behind, then retrieved the lead
  var bool bCameBack;                // team was loosing heavily, but went on a scoring streak and tied at least
  var bool bTookTheLead;             // this team score first and took the lead
  var bool bWasbehind;               // while the previous flag (any) was captured they were behind
  var bool bTiedScore;               // Team tied score on this capture
  var bool bLostleadAndWentBehind;   // Team not only lost lead before this capture, but also went behind

  var int TiedTheScoreTimes;         // How many times this team tied the score
  var int TimesTouchedFlag;          // How many times this team touched the flag. Used for calculating scoring efficiency
};

// ============================================================================
// ScorersAssistants struct
//
// holds information on who captured the flag, who assisted him, what is the
// score after this capture and when it happend
// ============================================================================

struct ScorersAssistants{
  var PlayerReplicationInfo Scorer;          // Player who captures the flag
  var PlayerReplicationInfo FirstAssistant;  // Player who held the flag before the Scorer
  var PlayerReplicationInfo SecondAssistant; // Player who held the flag before the First Assistant

  var string CurrentScore;                   // Score after this capture
  var string TimeStamp;                      // When this capture was made
};

// ============================================================================
// Headings struct:
//
// Simple struct containing all available heading for the summary
// Heading is the simple string with 4 (now) variables you can use:
// %w - winner-team name
// %l - loser-team name
// %c - point name ("capture" actually)
// %p - player who made the last capture of the game
// %o - total score (f.e. if game score was 3:1 thi will be replaced by 4)
// type - type of heading, defines situation when this heading should be used
// The available values for type are:
// 0 - shutout victory (a big score shut-out victory f.e. 7-0 or 5-0)
// 1 - solid (3 point difference - 6-2, 4-1 and so on )
// 2 - close score (1 point difference)
// 3 - comeback (was losing but took the lead and won) not implemented yet;
// 4 - overtime win
// 5 - comeback OT victory (managed to tie the match and win the overtime) not implemented yet;
// 6 - any other victory
// 7 - tie
// 8 - 0:0 tie
// 9 - big score match (9:5 and so on, losing team must score more at least 5 goals for this to be used)
//
// Note that the struct and the array, using this struct are configurable, so
// you can add you own headings
// ============================================================================
struct Headings{
  var globalconfig string Heading; // heading string
  var globalconfig int type;       // type of this heading, see explainations above
};

// ============================================================================
// array of Headings struct
// ============================================================================
var globalconfig array<Headings> HeadingsArray;

var localized string SummaryNameString;
var localized string SectionName;
var localized string SummaryNameProperty;

var string CurrentSummaryName;

// this will be a separate debug log
// var FileLog TempLog;

var Teams myTeams[2];                             // TeamInfo
var Controller FirstTouchBlue;                    // temp variable used for ??? deprecated?
var Controller FirstTouchRed;                     // temp variable used for ??? deprecated?

// this is used, as the flag's own Holder and Assists array are emptied, whe the flag returns to it's base. This is done BEFORE the TeamScoreEvent is called
var ScorersAssistants PotentialRedScorers;        // this used to keep current holder of the blue flag and the ones who held it before current holder
var ScorersAssistants PotentialBlueScorers;       // this used to keep current holder of the red flag and the ones who held it before current holder


var PlayerReplicationInfo GameWinningGoalScorer;  // PRI of player who made the capture, after which his team kept the lead till the end of the match
var CTFFlag FlagsInGame[2];                       // reference on both flags, to keep track of their holders and assists arrays

var array<ScorersAssistants> Goals;               // when the capture is made, PotentialRedScorers or PotentialBlueScorers is added to this array



// ============================================================================
//  Utility Functions, mostly return the correct strings based on the data provided
// ============================================================================
// This function recives seconds passed from
// the start of the match and converst them
// to the hours minutes & seconds
// ============================================================================
function String FormatTime( int Seconds, optional bool DoNotFix)
{
  local int Minutes, Hours, fixedSeconds;
  local String Time;

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// This is a fix for the Level.TimeDilation
// which is always equal to 1.1, so for the
// game, 20 minutes real time are equal to 22
// of in-game time. This resulte in showing
// that a 20 min game lasted 22 mins.
	if (!DoNotFix){
  	  fixedSeconds = int(Seconds / Level.TimeDilation);
	  Seconds = fixedSeconds;
	}
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  if( Seconds > 3600 )
  {
    Hours = Seconds / 3600;
    Seconds -= Hours * 3600;

    Time = Hours$":";
  }
  Minutes = Seconds / 60;
  Seconds -= Minutes * 60;

  if( Minutes >= 10 )
    Time = Time $ Minutes $ ":";
  else
    Time = Time $ "0" $ Minutes $ ":";

  if( Seconds >= 10 )
    Time = Time $ Seconds;
  else
    Time = Time $ "0" $ Seconds;

  return Time;
}


// ============================================================================
// TimeStamp
//
// Returns the string with current time
// from the start of the match
// ============================================================================
function string TimeStamp()
{
  local string seconds;
  local int SecInt;

  SecInt = int(Level.TimeSeconds);

  // if match started, substract the time that passed since the level loaded.
  if (bMatchStarted){
      SecInt = int(Level.TimeSeconds - MatchStartTime);
  }
  seconds = FormatTime(SecInt);

  return seconds;
}

// ============================================================================
// GetPercentage
//
//  A simple function to calculate how much percent of 'whole' 'part' is
// ============================================================================
function string GetPercentage(float part, float whole){
  local string result;
  local float hundreth;

  hundreth = whole/100;
  result = string(Max((int(part)/hundreth),0));
  return result$"%";
}

// ============================================================================
// DayOfWeekStr
//
// gets the day name depending on it's number in the week
// ============================================================================

function string DayOfWeekStr(int Num)
{
  if (Num == 1)
    return "Mon";
  if (Num == 2)
    return "Tue";
  if (Num == 3)
    return "Wed";
  if (Num == 4)
    return "Thu";
  if (Num == 5)
    return "Fri";
  if (Num == 6)
    return "Sat";
  else
    return "Sun";
}


// ============================================================================
// GetMonthStr
//
// gets the month name depending on it's number
// ============================================================================
function string MonthStr(int Num)
{
  if (Num == 1)
    return "Jan";
  if (Num == 2)
    return "Feb";
  if (Num == 3)
    return "Mar";
  if (Num == 4)
    return "Apr";
  if (Num == 5)
    return "May";
  if (Num == 6)
    return "Jun";
  if (Num == 7)
    return "Jul";
  if (Num == 8)
    return "Aug";
  if (Num == 9)
    return "Sep";
  if (Num == 10)
    return "Oct";
  if (Num == 11)
    return "Nov";
  if (Num == 12)
    return "Dec";
}

// ============================================================================
// TodayHourServerMap
//
// Creates and returns the string containing Date, hour, server name and map
// name
// ============================================================================

function string TodayHourServerMap(){
  local string Today;
  local string Hour;
  local string Server;
  local string Map;

  Today  = Level.Day@MonthStr(Level.Month)@Level.Year$", "$DayOfWeekStr(Level.DayOfWeek);
  Server = Level.Game.GameReplicationInfo.ServerName;
  Map    = GetMapFileName();
  if (Level.Minute < 10){
    Hour   = Level.Hour$":0"$Level.Minute;
  }
  else {
    Hour   = Level.Hour$":"$Level.Minute;
  }

  return Today$"."@Hour$"."@Server$"."@Map$".";
}

// ============================================================================
// ReportMapChange
//
// Checks if we want to report on map change and if so does additional checks
// ============================================================================

function bool ReportOnMapChange(){
  local bool bEnoughTime;
  local bool bEnoughPlayers;

  bEnoughPlayers = True;
  bEnoughTime = True;

  if (!bPostSummaryOnMapChange){
     return false;
  }
  else {
     if (MCSMinPlayers != 0){
        bEnoughPlayers = (Level.Game.NumPlayers >= MCSMinPlayers);
        Log("[DiscordLink]: Min players to report map change: "$bEnoughPlayers$" ("$MCSMinPlayers$")");
     }
     if (MCSMinTime != 0){
        bEnoughTime = (int(Level.TimeSeconds - MatchStartTime) >= (MCSMinTime*60));
        Log("[DiscordLink]: Min time to report map change: "$bEnoughTime$" ("$MCSMinTime$"m)");
     }

     if (MCSMinPlayers != 0 || MCSMinTime != 0)
        return bEnoughTime && bEnoughPlayers;

     return true;
  }

  return false;
}



// ============================================================================
//  GetHighestScore
//
// Finds the player with highest score
// ============================================================================

function string GetHighestScore(){
  local int i, j;
  local array<PlayerReplicationInfo> PRIs;
  local array<PlayerReplicationInfo> localPRIarray;
  local PlayerReplicationInfo PRI,t;

  localPRIarray = GRI.PRIArray;

  for (i = 0; i < localPRIarray.Length; i++){
    if ( Controller(localPRIarray[i].Owner).IsA('MessagingSpectator') || Controller(localPRIarray[i].Owner).IsA('DemoRecSpectator') || Controller(localPRIarray[i].Owner).IsInState('Spectating')){
      localPRIarray.Remove(i, 1);
      i = i - 1; // so the loop won't skip the next entry
    }
  }

 for (i=0;i<localPRIarray.Length;i++)
  {
    PRI = localPRIarray[i];

    PRIs.Length = PRIs.Length+1;
    for (j=0;j<Pris.Length-1;j++)
    {
      if (PRIs[j].Score < PRI.Score ||
           (PRIs[j].Score == PRI.Score && PRIs[j].Deaths > PRI.Deaths)
      )
      {
        t = PRIs[j];
        PRIs[j] = PRI;
        PRI = t;
      }
    }
    PRIs[j] = PRI;
  }

  return PRIs[0].PlayerName@"("$PRIs[0].Team.TeamName$") - with score of"@int(PRIs[0].Score)$".";
}


function string GetMostFlagReturns(){
  local int i, j;
  local array<PlayerReplicationInfo> PRIs;
  local array<PlayerReplicationInfo> localPRIarray;
  local PlayerReplicationInfo PRI,t;

  localPRIarray = GRI.PRIArray;

  for (i=0;i<localPRIarray.Length;i++)
  {
    PRI = localPRIarray[i];

    PRIs.Length = PRIs.Length+1;
    for (j=0;j<Pris.Length-1;j++)
    {
      if (TeamPlayerReplicationInfo(PRIs[j]).FlagReturns < TeamPlayerReplicationInfo(PRI).FlagReturns ||
           (TeamPlayerReplicationInfo(PRIs[j]).FlagReturns == TeamPlayerReplicationInfo(PRI).FlagReturns && PRIs[j].Score < PRI.Score)
      )
      {
        t = PRIs[j];
        PRIs[j] = PRI;
        PRI = t;
      }
    }
    PRIs[j] = PRI;
  }

  for (i = 0; i < PRIs.Length; i++){
    if ( Controller(PRIs[i].Owner).IsA('MessagingSpectator') || Controller(PRIs[i].Owner).IsA('DemoRecSpectator') || Controller(PRIs[i].Owner).IsInState('Spectating')){
     PRIs.Remove(i, 1);
     i = i - 1; // so the loop won't skip the next entry.
    }
  }

  return PRIs[0].PlayerName@"("$PRIs[0].Team.TeamName$") - returned"@TeamPlayerReplicationInfo(PRIs[0]).FlagReturns@"flags.";
}


function string GetThreeStars(){
  local string result;
  local int i, j;
  local array<PlayerReplicationInfo> PRIs;
  local PlayerReplicationInfo PRI,t;

  for (i=0;i<GRI.PRIArray.Length;i++)
  {
    PRI = GRI.PRIArray[i];

    // quick cascade sort to find out which player helped more to their team
    PRIs.Length = PRIs.Length+1;
    for (j=0;j<Pris.Length-1;j++)
    {
      // Warning!
      // Reading the following "if" statement may completely blow off your mind;
      // Summary:
      // if select the player who scored more by completeing objectives (score - kills = score_for_objectives)
      // if two or more players have the same score, check their frags (kills - suicides = frags)
      // if these two values are also equal, then check who died less
      if ( !PRIs[j].bOnlySpectator && PRIs[j].PlayerName != "WebAdmin" && PRIs[j].PlayerName != "DemoRecSpectator" && PRIS[j].Team != None && ((PRIs[j].Score - (PRIs[j].Kills - TeamPlayerReplicationInfo(PRIs[j]).Suicides) < (PRI.Score - (PRI.Kills - TeamPlayerReplicationInfo(PRI).Suicides) )) || ((PRIs[j].Score - (PRIs[j].Kills - TeamPlayerReplicationInfo(PRIs[j]).Suicides)) == (PRI.Score - (PRI.Kills - TeamPlayerReplicationInfo(PRI).Suicides)) && ((PRIs[j].Kills - TeamPlayerReplicationInfo(PRIs[j]).Suicides) < (PRI.Kills - TeamPlayerReplicationInfo(PRI).Suicides))) || ((PRIs[j].Score - (PRIs[j].Kills - TeamPlayerReplicationInfo(PRIs[j]).Suicides)) == (PRI.Score - (PRI.Kills - TeamPlayerReplicationInfo(PRI).Suicides)) && ( (PRIs[j].Kills - TeamPlayerReplicationInfo(PRIs[j]).Suicides) == (PRI.Kills - TeamPlayerReplicationInfo(PRI).Suicides)) ) &&  PRIs[j].Deaths > PRI.Deaths))
      {
        t = PRIs[j];
        PRIs[j] = PRI;
        PRI = t;
      }
    }
    PRIs[j] = PRI;
  }

  for (i = 0; i < PRIs.Length; i++){
    if ( Controller(PRIs[i].Owner).IsA('MessagingSpectator') || Controller(PRIs[i].Owner).IsA('DemoRecSpectator') || Controller(PRIs[i].Owner).IsInState('Spectating') || PRIs[i].Team == None ){
      PRIs.Remove(i, 1);
      i = i - 1; // so the loop won't skip the next entry.
      }
  }


  result = PRIs[0].PlayerName@"("$PRIs[0].Team.TeamName$"),";
  result = result@PRIs[1].PlayerName@"("$PRIs[1].Team.TeamName$"),";
  result = result@PRIs[2].PlayerName@"("$PRIs[2].Team.TeamName$").";

  return result;
}

// ============================================================================
// CreateHeading
//
// selects the heading from the headings array depending on the final score,
// replaces variables in it and returns the ready-to-use string
// ============================================================================
function string CreateHeading(String LastScorer){

  local teamInfo losers;

  local bool bShutOut;       // Only one team scored in this game - shut-out
  local bool bSolid;         // A solid victory with 3 points gap
  local bool bTight;    // A tough game when only one point difference in the end
  local bool bDraw;          // resultive draw (1:1. 4:4, etc)
  local bool bZeroDraw;      // 0:0 draw
  local bool bOneWay;
//  local bool bComeback;
  local bool bAllOutAttack;  // both teams played with little or no defence - huge score like 7:8

  local string result;       // the created heading will be returned via this var
  local string point;        // point for this gametype. to replace %p in heading

  local int TotalScore;   // this string will replace the %o in headings
  local int i;
  local int l;
  local int headnum;

  local array<string> SuitableHeadings; // The array with headings of the type that suits for this game score

  point = "capture";


  // defining who's who
  if (GRI.Teams[0].Score > GRI.Teams[1].Score){
    winners = GRI.Teams[0];
    losers = GRI.Teams[1];
  }
  else{
    winners = GRI.Teams[1];
    losers = GRI.Teams[0];
  }

  TotalScore = int(winners.Score + losers.Score);  // setting the TotalScore

  if (!bFlavorHeading){
    return winners.TeamName@"wins the match!";
  }

  // losers scored 0, winners 5 and more (f.e. 0:5, 0:7, 0:8)
  if (losers.Score == 0 && winners.Score > 4)
   bShutOut = true;

  if (!bShutOut && TotalScore > 8 && (winners.Score - losers.Score) > 5 )
   bOneWay = true;

  // losers scored at least half of goalscore.
  if ( TotalScore > 10 && (winners.Score - losers.Score) >= 2  )
   bAllOutAttack = true;

  // losers score any less than 5, winners - 3+ more than losers (f.e. 1:4, 4:7, 2:8)
  if ((int(winners.Score - losers.Score) >= 3) && !bAllOutAttack && !bShutOut && !bOneWay)
   bSolid = true;

  // if the score is not huge and the difference is only 1 point (f.e. 0:1, 3:4, 4:5)
  if (int(winners.Score - losers.Score) == 1 && !bAllOutAttack)
   bTight=True;

  // resultive draw (f.e. 1:1, 4:4, 5:5). for a forced end of game
  if (GRI.Teams[0].Score == GRI.Teams[1].Score)
   bDraw = True;

  // 0:0 draw (if someone forcibly stopped before someone scored)
  if ( (GRI.Teams[0].Score == GRI.Teams[1].Score) && int(GRI.Teams[0].Score) == 0)
   bZeroDraw = True;

  // Looking through available headings and picking the ones of the matching type;
  if (bShutOut && !bOverTime){
    for (i = 0; i < HeadingsArray.Length; i++){
      if (HeadingsArray[i].type == 0){
        l = SuitableHeadings.Length;
        SuitableHeadings.Length = l + 1;
        SuitableHeadings[l] = HeadingsArray[i].Heading;
      }
    }
  }

  if (bOneWay){
    for (i = 0; i < HeadingsArray.Length; i++){
      if (HeadingsArray[i].type == 10){
        l = SuitableHeadings.Length;
        SuitableHeadings.Length = l + 1;
        SuitableHeadings[l] = HeadingsArray[i].Heading;
      }
    }
  }

  if (!bShutOut && !bOneWay && bSolid && !bOverTime){
    for (i = 0; i < HeadingsArray.Length; i++){
      if (HeadingsArray[i].type == 1){
        l = SuitableHeadings.Length;
        SuitableHeadings.Length = l + 1;
        SuitableHeadings[l] = HeadingsArray[i].Heading;
      }
    }
  }

  if (bTight && !bOvertime){
    for (i = 0; i < HeadingsArray.Length; i++){
      if (HeadingsArray[i].type == 2){
        l = SuitableHeadings.Length;
        SuitableHeadings.Length = l + 1;
        SuitableHeadings[l] = HeadingsArray[i].Heading;
      }
    }
  }

  if (bOverTime){
    for (i = 0; i < HeadingsArray.Length; i++){
      if (HeadingsArray[i].type == 4){
        l = SuitableHeadings.Length;
        SuitableHeadings.Length = l + 1;
        SuitableHeadings[l] = HeadingsArray[i].Heading;
      }
    }
  }

  if (bDraw && !bZeroDraw){
    for (i = 0; i < HeadingsArray.Length; i++){
      if (HeadingsArray[i].type == 7){
        l = SuitableHeadings.Length;
        SuitableHeadings.Length = l + 1;
        SuitableHeadings[l] = HeadingsArray[i].Heading;
      }
    }
  }

  if (bZeroDraw){
    for (i = 0; i < HeadingsArray.Length; i++){
      if (HeadingsArray[i].type == 8){
        l = SuitableHeadings.Length;
        SuitableHeadings.Length = l + 1;
        SuitableHeadings[l] = HeadingsArray[i].Heading;
      }
    }
  }

  if (bAllOutAttack){
    for (i = 0; i < HeadingsArray.Length; i++){
      if (HeadingsArray[i].type == 9){
        l = SuitableHeadings.Length;
        SuitableHeadings.Length = l + 1;
        SuitableHeadings[l] = HeadingsArray[i].Heading;
      }
    }
  }

  // a usual win like 2:0
  if (!bDraw && !bZeroDraw && !Level.Game.bOverTime && !bTight && !bShutOut && !bSolid && !bOneWay){
    for (i = 0; i < HeadingsArray.Length; i++){
      if (HeadingsArray[i].type == 6){
        l = SuitableHeadings.Length;
        SuitableHeadings.Length = l + 1;
        SuitableHeadings[l] = HeadingsArray[i].Heading;
      }
    }
  }

  headnum    = Rand(SuitableHeadings.Length-1);       // randomly selectinga a header amnong picked ones
  result     = SuitableHeadings[headnum];             // setting result to that heading

  // replacing variables in the heading
  ReplaceText(result, "%w", winners.TeamName);
  ReplaceText(result, "%l", losers.TeamName);
  ReplaceText(result, "%c", point);
  ReplaceText(result, "%p", LastScorer);
  ReplaceText(result, "%o", string(TotalScore));

  // returning the finished heading
  return result;
}


function UpdateScores()
{
  RedScore = int(GRI.Teams[0].Score);
  BlueScore = int(GRI.Teams[1].Score);
}

//====================================
// Builds a list of objectives or
// updates the time. This should be called once per objective, so we should be
//====================================
function UpdateASObjList(int TeamIndex, string Objective, int RoundTime){
   local int i, x;

//   Log("[DiscordLink] Updating objective list:"@TeamIndex@Objective@RoundTime);

   // red team always starts first so we just add the item
   if (TeamIndex == 0){
     x = ASObjectives.Length;
     ASObjectives.Length = x + 1;
     ASObjectives[x].ObjDescription = Objective;
     ASObjectives[x].RedTime = FormatTime(RoundTime, True);
     Log("[DiscordLink] Red team completed objective:"@ASObjectives[x].ObjDescription@"at"@ASObjectives[x].RedTime);
   }
   // blue is more complicated since we need to re-use old if there is one and create new if there's a new one
   else {
     for (i = 0; i < ASObjectives.Length; i++){
        // find the first entry that has no time set for blue, update it and stop
        if (ASObjectives[i].ObjDescription == Objective && ASObjectives[i].BlueTime == ""){
           ASObjectives[i].ObjDescription = Objective;
           ASObjectives[i].BlueTime = FormatTime(RoundTime, True);
           Log("[DiscordLink] Blue team completed objective:"@ASObjectives[x].ObjDescription@"at"@ASObjectives[x].RedTime);
           return;
        }
     }
     // we didn't find anything, so we didn't hit the return, means it's a new objective Red didn't reach;
     x = ASObjectives.Length;
     ASObjectives.Length = x + 1;
     ASObjectives[x].ObjDescription = Objective;
     ASObjectives[x].BlueTime = FormatTime(RoundTime, True);
   }
}


//====================================
// OLStats Compatibility
//
// If OLStats is enabled passes all calls to the OLStats that we spawned
//====================================


function ServerInfo()
{
  if (OLSLogger!=None){
    OLSLogger.ServerInfo();
  }
}

function Shutdown()
{
  if (OLSLogger!=None){
    OLSLogger.Shutdown();
  }
}

function Logf(string LogString)
{
  if (OLSLogger!=None){
    OLSLogger.Logf(LogString);
  }
}

function ConnectEvent(PlayerReplicationInfo Who)
{
  if (OLSLogger!=None){
    OLSLogger.ConnectEvent(Who);
  }
}

function DisconnectEvent(PlayerReplicationInfo Who)
{
  if (OLSLogger!=None){
    OLSLogger.DisconnectEvent(Who);
  }
}

function KillEvent(string Killtype, PlayerReplicationInfo Killer, PlayerReplicationInfo Victim, class<DamageType> Damage)
{
  if (OLSLogger!=None){
    OLSLogger.KillEvent(Killtype,Killer,Victim,Damage);
  }
}

//====================================
// Fill the settings in WebAdmin
//
//====================================

static function FillPlayInfo(PlayInfo PlayInfo)
{
	if (default.Priv < 0 || default.Priv > 255){
	  default.Priv = 1;
	}
  PlayInfo.AddClass(default.Class);
  PlayInfo.AddSetting("Discord Link Settings",       "bOLStatsEnabled",      default.DescString[0],  default.Priv, 1,  "Check");
  PlayInfo.AddSetting("Discord Link Settings",       "bReportMatchStart",    default.DescString[1],  default.Priv, 2,  "Check");
  PlayInfo.AddSetting("Discord Link Settings",       "bReportScoreEvents",   default.DescString[2],  default.Priv, 2,  "Check");
  PlayInfo.AddSetting("Discord Link Settings",       "bPostCapSummary",      default.DescString[3],  default.Priv, 2,  "Check");
  PlayInfo.AddSetting("Discord Link Settings",       "bReportSpreesStreaks", default.DescString[4],  default.Priv, 2,  "Check");
  PlayInfo.AddSetting("Discord Link Settings",       "bFlavorHeading",       default.DescString[5],  default.Priv, 2,  "Check");
  PlayInfo.PopClass();
  super.FillPlayInfo(PlayInfo);
}

static event string GetDescriptionText(string PropName)
{
	switch (PropName)
	{
		case "bOLStatsEnabled":
			return default.DescString[0];
		case "bReportMatchStart":
			return default.DescString[1];
		case "bReportScoreEvents":
			return default.DescString[2];
		case "bPostCapSummary":
			return default.DescString[3];
		case "bReportSpreesStreaks":
			return default.DescString[4];
		case "bFlavorHeading":
			return default.DescString[5];
	}
}


//====================================
// The actual functions that do the work
//
//====================================


function PreBeginPlay()
{
//  local class<GameStats> OLSL;
  Super.PreBeginPlay();

  //Initializing World Stats Logging support
  if (bOLStatsEnabled){
//    OLSL = class<GameStats>(DynamicLoadObject("OLStats.OLGameStats", class'Class'));
    OLSLogger = spawn(class<GameStats>(DynamicLoadObject("OLStats.OLGameStats", class'Class')));
    OLSLogger.GRI = Level.Game.GameReplicationInfo;
  Log("[DiscordLink] World Stats logging support initialized.");
  }
}


// ============================================================================
// NewGame
//
// New match has started
// ============================================================================

function NewGame()
{
  local Mutator Mut;
  local CTFFlag testFlag;

  GRI = Level.Game.GameReplicationInfo;

  foreach AllActors(class'Mutator',Mut)
  {
    if (Left(Mut.FriendlyName, 6) ~= "UTComp"){
       Log("[DiscordLink]: Detected UTComp");
       bUTCompIsPresent = True;
    }
	if (Mut.IsA('MutLDiscordReport')){
	   DRP = MutLDiscordReport(Mut);
	}
  }

  bFirstScore = true;

  myTeams[0].thisTeam = GRI.Teams[0];
  myTeams[1].thisTeam = GRI.Teams[1];

  myTeams[0].TiedTheScoreTimes = 0;
  myTeams[0].TimesTouchedFlag  = 0;
  myTeams[1].TiedTheScoreTimes = 0;
  myTeams[1].TimesTouchedFlag  = 0;

  if (OLSLogger != None){
     OLSLogger.NewGame();
  }
  if (Level.Game.bTeamGame){
    GRI.Teams[1].TeamName = "Blue Team";
    GRI.Teams[0].TeamName = "Red Team";
  }

  ForEach AllActors(Class'CTFFlag', testFlag){
    log("[DiscordLink] Found CTFFlag:"@testFlag);

     if (TestFlag.TeamNum == 0){
       FlagsInGame[0] = TestFlag;
     }
     else if (TestFlag.TeamNum == 1){
       FlagsInGame[1] = TestFlag;
     }
  }

  // Flags are assigned, now starting the timer, so, we can track their state
  SetTimer(0.5, True);

}




// ============================================================================
//  StartGame
// Called when match starts
// ============================================================================
function StartGame()
{
  local bool bWarmup;

  bWarmUp = false;
  GRI = Level.Game.GameReplicationInfo;
	// I don't know how Epics deal with the StartGame being called twice
	// with UTComp - it's their own business, so I'll let the things as
	// they are w/out GameLogger.

  if (OLSLogger!=None){
    OLSLogger.StartGame();
  }

//   Log("[DiscordLink]: bUTCompWarmUpStarted:"@bUTCompWarmUpStarted);

  if ( bUTCompIsPresent ){
    bWarmup = bool(ConsoleCommand("get mututcomp bEnableWarmup"));
//    Log("[DiscordLink]: UTComp Warmup enabled:"@bWarmup);
    if (bWarmup && !bUTCompWarmUpStarted){
	    bUTCompWarmUpStarted = True;
		Log("[DiscordLink]: UTComp is detected and warmup is enabled");
		Log("[DiscordLink]: bWarmup:"@bWarmUp);
		Log("[DiscordLink]: bMatchStarted:"@bUTCompWarmUpStarted);
  	}
  	else if (bWarmup && bUTCompWarmUpStarted){
      bMatchStarted = True;
      Log("[DiscordLink]: UTComp is detected and warmup is over, starting the game");
	  Log("[DiscordLink]: bMatchStarted:"@bUTCompWarmUpStarted);
    }
    else{
      bMatchStarted = True;
      Log("[DiscordLink]: UTComp is detected but warmup is disabled, starting the game");
	  Log("[DiscordLink]: bMatchStarted:"@bUTCompWarmUpStarted);
    }
  }
  else{
    bMatchStarted = true;
	myTeams[0].TimesTouchedFlag = 0;
	myTeams[1].TimesTouchedFlag = 0;
  }



  if (bMatchStarted){
	MatchStartTime = Level.TimeSeconds;

    if (ASGameinfo(Level.Game) !=  None ){
	  DRP.SendMSG("ASMST"$Level.TimeSeconds$";"$ASGameinfo(Level.Game).RoundTimeLimit$";"$ASGameinfo(Level.Game).ReinforcementsFreq$"s;"$(ASGameinfo(Level.Game).RoundLimit)$";"$GetMapFileName());
	}
	else {
	  DRP.SendMSG("MSTRT"$Level.TimeSeconds$";"$Level.Game.GoalScore$";"$Level.Game.TimeLimit$";"$Level.Game.default.GameName$";"$GetMapFileName());
	}
  }
}


// ============================================================================
//  ScoreEvent
// Called when one of the players increases his/her score
// Using these for individual score events to name the player
// ============================================================================
function ScoreEvent(PlayerReplicationInfo Who, float Points, string Desc)
{

  if (!bMatchStarted)
	return;

  GRI = Level.Game.GameReplicationInfo;

  if (Level.Game.bTeamGame){
    UpdateScores();
  }

//  log("ScoreEvent:"$Desc);
  if (Desc == "flag_cap_final"){
    DRP.SendMSG("CTFFC"$TimeStamp()$";"$RedScore$";"$BlueScore$";"$Who.PlayerName$";"$Who.Team.TeamName$";"$Who.Team.TeamIndex);
  }

  if (Desc == "ball_cap_final"){
    DRP.SendMSG("BRTCD"$TimeStamp()$";"$RedScore$";"$BlueScore$";"$Who.PlayerName$";"$Who.Team.TeamName$";"$Who.Team.TeamIndex);
  }
  if (Desc == "ball_thrown_final"){
    DRP.SendMSG("BRTSS"$TimeStamp()$";"$RedScore$";"$BlueScore$";"$Who.PlayerName$";"$Who.Team.TeamName$";"$Who.Team.TeamIndex);
  }

  if (OLSLogger!=None){
    OLSLogger.ScoreEvent(Who,Points,Desc);
  }

}


// ============================================================================
//  TeamScoreEvent
// Called when one of the teams increases its score
// ============================================================================
function TeamScoreEvent(int Team, float Points, string Desc)
{
  local int opponent, l;

  if (OLSLogger!=None){
    OLSLogger.TeamScoreEvent(Team,Points,Desc);
  }

  if (!bMatchStarted || Desc ~= "tdm_frag" || Desc ~= "team_frag" )
	return;

  GRI = Level.Game.GameReplicationInfo;
  UpdateScores();

  // getting opponent index
  if (team == 0){
    opponent = 1;
  }
  else{
    opponent = 0;
  }

  // that's the first capture of the game; setting initial values for both teams
  if (bFirstScore){
    myTeams[team].bTookTheLead   = True;
    myTeams[opponent].bWasbehind = true;

    bFirstScore = false;

    // someone scored first goal of the game. if his team will keep the lead,
    // he'll be the GWG scorer;
    if (team == 1){
      GameWinningGoalScorer = PotentialRedScorers.Scorer;
    }
    else{
      GameWinningGoalScorer = PotentialBlueScorers.Scorer;
    }

  }
// ===========================================================================
// This section of function is under construction;
// Actually only 12 or so lines relating to determining GWG scorer are
// working here now
// ===========================================================================
  // score just tied
  if (myTeams[team].thisTeam.Score == myTeams[opponent].thisTeam.Score){
    GameWinningGoalScorer = None;// score is tied, GWG race starts again;

    if (myTeams[team].bWasBehind){
      myTeams[opponent].bLostlead     = True;
      myTeams[opponent].brestoredlead = false;
      myTeams[opponent].bReturnedlead = false;
      myTeams[team].bTiedScore=True;
      myTeams[team].TiedTheScoreTimes += 1;
    }
    else{
      myTeams[team].bLostlead=True;
      myTeams[team].brestoredlead=false;
      myTeams[opponent].bTiedScore=True;
      myTeams[opponent].TiedTheScoreTimes += 1;
    }
  }

  // WORKING GUIDE. To save time on scrolling to the heading and back
  //  var bool bLostlead;
  //  var bool brestoredlead;
  //  var bool bReturnedlead;
  //  var bool bCameBack;
  //  var bool bTookTheLead;
  //  var bool bWasbehind;
  //  var bool bTiedScore;
  //  var bool bLostleadAndWentBehind;
  //  var int TiedTheScoreTimes;

  if (myTeams[team].thisTeam.Score > myTeams[opponent].thisTeam.Score){
    if (myTeams[opponent].bTiedScore){
      myTeams[team].brestoredlead  = true;
      myTeams[opponent].bTiedScore = false;

      // so, if this opposite team tied the score but scoring team went ahead again,
      // the one who scored is most likely to became GWG scorer;
      if (team == 1){
        GameWinningGoalScorer = PotentialRedScorers.Scorer;
      }
      else{
        GameWinningGoalScorer = PotentialBlueScorers.Scorer;
      }
    }
    else if (myTeams[team].bTiedScore){
      myTeams[opponent].bLostleadAndWentBehind = True;
      myTeams[opponent].brestoredlead          = false;
      myTeams[opponent].bReturnedlead          = false;

      myTeams[team].bTiedScore = false;
      myTeams[team].bWasBehind = false;
      // if this team tied the score but again went ahead, the one who scored is
      // most likely to became GWG scorer;
      if (team == 1){
        GameWinningGoalScorer = PotentialRedScorers.Scorer;
      }
      else{
        GameWinningGoalScorer = PotentialBlueScorers.Scorer;
      }
    }
    else if (myTeams[team].bLostlead){
      myTeams[team].bLostlead      = false;
      myTeams[team].brestoredlead  = true;
      myTeams[opponent].bTiedScore = false;
    }
     else if (myTeams[team].bLostleadAndWentBehind){
      myTeams[team].bLostleadAndWentBehind = false;
      myTeams[team].bReturnedlead          = true;
      myTeams[opponent].bLostleadAndWentBehind = true;
      myTeams[opponent].bLostLead              = True;
    }
  }
// ===========================================================================
// End of under construction section
//
// ===========================================================================

   // Filling the goals array with the current appropriate PotentialScorers array
    if (CTFGame(Level.Game) != None){
      if(team == 1){
        l = Goals.Length;

        Goals.Length          = l + 1;
        Goals[l]              = PotentialRedScorers;
        Goals[l].TimeStamp    = TimeStamp(); //
        Goals[l].CurrentScore = int(myTeams[0].thisTeam.Score)$":"$int(myTeams[1].thisTeam.Score);

        PotentialRedScorers.Scorer          = None; // so we've set the Goals to PotentialScorers
        PotentialRedScorers.FirstAssistant  = None; // now we can empty all values
        PotentialRedScorers.SecondAssistant = None; // just to avoid any problems
      }
      else{
        l = Goals.Length;
        Goals.Length          = l + 1;
        Goals[l]              = PotentialBlueScorers;
        Goals[l].TimeStamp    = TimeStamp();
        Goals[l].CurrentScore = int(myTeams[0].thisTeam.Score)$":"$int(myTeams[1].thisTeam.Score);

        PotentialBlueScorers.Scorer          = None;
        PotentialBlueScorers.FirstAssistant  = None;
        PotentialBlueScorers.SecondAssistant = None;
    }
  }


  log("[DiscordLink] TeamScoreEvent:"$Desc);
  if (Desc ~= "enemy_core_destroyed"){
	DRP.SendMSG("ONSCD"$TimeStamp()$";"$RedScore$";"$BlueScore$";"$Team$";"$GRI.Teams[Team].TeamName);
  }

  if (Desc ~= "round_win"){
	DRP.SendMSG("TGRND"$TimeStamp()$";"$RedScore$";"$BlueScore$";"$Team$";"$GRI.Teams[Team].TeamName);
  }

  if (Desc ~= "pair_of_round_winner"){
    ASGRI = ASGameReplicationInfo(GRI);
	DRP.SendMSG("ASRDW"$TimeStamp()$";"$RedScore$";"$BlueScore$";"$Team$";"$ASGRI.GetRoundWinnerString());
  }

}

// ============================================================================
// SpecialEvent
//
// Logs special events like sprees, multikills combo activations, etc.
// ============================================================================

function SpecialEvent(PlayerReplicationInfo Who, string Desc)
{
  if (OLSLogger!=None){
    OLSLogger.SpecialEvent(Who,Desc);
  }

  if (!bMatchStarted)
	  return;

  if (Desc ~= "multikill_7"){
	DRP.SendMSG("PSEHS"$TimeStamp()$";"$Who.PlayerName);
  }
  if (Desc ~= "spree_5"){
	DRP.SendMSG("PSEGL"$TimeStamp()$";"$Who.PlayerName);
  }
}

// ============================================================================
// Timer
//
// Tracks if the flag is at his placeholder and if not keeps trackinh who holds
// it and if there any assistants for this flag. This is done so because the
// flag simply resets this information JUST before reporting a capture, so we
// can't check them in TeamScoreEvent. So we recreate this vars here and if the
// flag is not on the base we update them with approprite vars form it, and
// when someone scores just write down appropriate values from local copies
// ============================================================================

function Timer(){
  local int i;

	if (!bMatchStarted)// Don't do anything before the match starts
	  return;

  if(CTFGame(Level.Game) != None){
	if (FlagsInGame[1].Location != FlagsInGame[1].HomeBase.Location){
    // do the below stuff ONLY when flag is not in his placeholder

      // getting the current flag holder
      for (i=0; i<GRI.PRIArray.Length; i++){
        if ( GRI.PRIArray[i].HasFlag == FlagsInGame[1]){
          PotentialBlueScorers.Scorer = GRI.PRIArray[i];
        }
      }

      // getting assists
      // note: the last assist == scorer if scorer != firstTouch
      if (FlagsInGame[1].Assists.length >= 3){ // there are at least two assistants
        PotentialBlueScorers.FirstAssistant  = FlagsInGame[1].Assists[FlagsInGame[1].Assists.length-2].PlayerReplicationInfo;
        PotentialBlueScorers.SecondAssistant = FlagsInGame[1].Assists[FlagsInGame[1].Assists.length-3].PlayerReplicationInfo;
      }

      else if (FlagsInGame[1].Assists.length == 2){
        PotentialBlueScorers.FirstAssistant = FlagsInGame[1].Assists[0].PlayerReplicationInfo;
        if (FlagsInGame[1].FirstTouch.PlayerReplicationInfo != PotentialBlueScorers.Scorer)
          PotentialBlueScorers.SecondAssistant = FlagsInGame[1].FirstTouch.PlayerReplicationInfo;
      }

      else if (FlagsInGame[1].Assists.length == 1){
        if (FlagsInGame[1].FirstTouch.PlayerReplicationInfo != PotentialBlueScorers.Scorer)
          PotentialBlueScorers.FirstAssistant = FlagsInGame[1].FirstTouch.PlayerReplicationInfo;
      }
      // just a check, so one player won't be mentioned in assistants twice
      if (PotentialBlueScorers.FirstAssistant == PotentialBlueScorers.SecondAssistant)
        PotentialBlueScorers.SecondAssistant = None;
    }

    // the same as the above, but for another flag
    if (FlagsInGame[0].Location != FlagsInGame[0].HomeBase.Location){

      for (i=0; i<GRI.PRIArray.Length; i++){
        if ( GRI.PRIArray[i].HasFlag == FlagsInGame[0]){
          PotentialRedScorers.Scorer = GRI.PRIArray[i];
        }
      }

      // note: the last assist == scorer if scorer != firstTouch
      if (FlagsInGame[0].Assists.length >= 3){
        PotentialRedScorers.FirstAssistant  = FlagsInGame[0].Assists[FlagsInGame[0].Assists.length-2].PlayerReplicationInfo;
        PotentialRedScorers.SecondAssistant = FlagsInGame[0].Assists[FlagsInGame[0].Assists.length-3].PlayerReplicationInfo;
      }

      else if (FlagsInGame[0].Assists.length == 2){
        PotentialRedScorers.FirstAssistant = FlagsInGame[0].Assists[0].PlayerReplicationInfo;
        if (FlagsInGame[0].FirstTouch.PlayerReplicationInfo != PotentialRedScorers.Scorer)
          PotentialRedScorers.SecondAssistant = FlagsInGame[0].FirstTouch.PlayerReplicationInfo;
      }

      else if (FlagsInGame[0].Assists.length == 1){
        if (FlagsInGame[0].FirstTouch.PlayerReplicationInfo != PotentialRedScorers.Scorer)
          PotentialRedScorers.FirstAssistant = FlagsInGame[0].FirstTouch.PlayerReplicationInfo;
      }

      if (PotentialRedScorers.FirstAssistant == PotentialRedScorers.SecondAssistant)
        PotentialRedScorers.SecondAssistant = None;
    }
  }

  // overtime check
  if (Level.Game.bOverTime && !bWasOvertime){
    if (Level.Game.bTeamGame){
      DRP.SendMSG("TBMOT"$Timestamp()$";"$int(GRI.Teams[0].Score)$";"$int(GRI.Teams[1].Score)); // we still need to send timestamp as it's used by the Py server deduplication feature
    }
    else {
      DRP.SendMSG("GENOT"$Timestamp()$";"$int(GRI.Teams[0].Score)$";"$int(GRI.Teams[1].Score)); // we still need to send timestamp as it's used by the Py server deduplication feature
    }
   bOvertime = true;
   bWasOvertime = true;
  }
}

// ============================================================================
// GameEvent
//
// If the event is "flag_taken" (flag was taken from it's base if from
// the ground is "flag_pickup"), we're increasing the TimesTouchedFlag for the
// appropriate team, so we can get total number of attempts to steal the flag
// by that team.
//
// Note: for the "flag_taken" event as a desc, CTFFlag, which sends this GEvent
// to GameStats, passes the index of team who owns that taken flag, not the one
// who took it.
// ============================================================================
function GameEvent(string GEvent, string Desc, PlayerReplicationInfo Who){
  local array<string> AS_Objective;
  local string Objective, sRoundTime;
  local int i, RoundTime;

  if (OLSLogger!=None){
    OLSLogger.GameEvent(GEvent,Desc,Who);
  }

  // AS times are not straightforward, as we care about the round time and not time since match started.
  if (ASGameInfo(Level.Game) != None && bMatchStarted) {
    ASGRI = ASGameReplicationInfo(GRI);

	RoundTime = Max(0, ASGameInfo(Level.Game).RoundStartTime - ASGameInfo(Level.Game).RemainingTime);
    if ( ASGRI.RoundWinner != ERW_None )
	  RoundTime = ASGRI.RoundOverTime;

    sRoundTime = FormatTime(RoundTime, True);
  }

  if (GEvent == "flag_taken" && bMatchStarted){
    if (Desc == "1"){ // see note above
      myTeams[0].TimesTouchedFlag++;
    }
    else {
      myTeams[1].TimesTouchedFlag++;
    }
  }

  if (GEvent == "ObjectiveCompleted_Trophy" && bMatchStarted){
    // workaround to filter out the first two fields we don't need out of a precompiled objective string in World Stats Logger format, that uses SPACES for separators to get a human readable name of the objective
	Split(Desc, " ", AS_Objective);
	for (i=2; i<AS_Objective.Length; i++){
	  Objective = Objective@AS_Objective[i];
	}
	UpdateASObjList(Who.Team.TeamIndex,Objective,RoundTime);
	DRP.SendMSG("ASEVT"$sRoundTime$";"$Who.PlayerName$";"$Who.Team.TeamName$";"$Who.Team.TeamIndex$";"$Objective);
  }

  if ((GEvent == "AS_attackers_win" || GEvent == "AS_defenders_win") && bMatchStarted){
     if (GEvent == "AS_attackers_win" && Desc == "0")
       DRP.SendMSG("ASRDE"$sRoundTime$";"$Desc$";Red team successfully attacked");
     if (GEvent == "AS_attackers_win" && Desc == "1")
       DRP.SendMSG("ASRDE"$sRoundTime$";"$Desc$";Blue team successfully attacked");
     if (GEvent == "AS_defenders_win" && Desc == "0")
       DRP.SendMSG("ASRDE"$sRoundTime$";"$Desc$";Red team successfully defended");
     if (GEvent == "AS_defenders_win" && Desc == "1")
       DRP.SendMSG("ASRDE"$sRoundTime$";"$Desc$";Blue team successfully defended");
  }
}

function EndGame(string Reason)
{
  local int i,j;
  local string RedPlayers, BluePlayers;
  local string RedScores, BlueScores;
  local string RedCaptures, BlueCaptures;
  local string RedObjectives, BlueObjectives;
  local string RedEff, BlueEff;
  local string ThreeStars;
  local string RedScoreAttempts, BlueScoreAttempts;
  local string Heading;
  local string FinalScore;
  local string Scorers;
  local string Objectives, RedTimes, BlueTimes;
  local string matchinfo;
  local string LastScorer;
  local array<PlayerReplicationInfo> PRIs;
  local PlayerReplicationInfo PRI,t;


  if (OLSLogger!=None){
    OLSLogger.EndGame(Reason);
  }

  if ( (Reason ~= "mapchange" && !ReportOnMapChange() )|| Reason ~= "serverquit" ){
    Log("[DiscordLink] EndGame reason is"@Reason$", not sending a report");
	return;
  }

  if (!bMatchStarted){
    Log("[DiscordLink] Match hasn't started, not sending a report");
	return;

  }

  Log("[DiscordLink] Match ended");

  if (ASGameInfo(Level.Game) != None){
    ASGRI = ASGameReplicationInfo(GRI);
  }

  if (GRI.Teams[0].Score > GRI.Teams[1].Score){
    Winners = GRI.Teams[0];
  }
  else{
    Winners = GRI.Teams[1];
  }

  SetTimer(0.5, false);
  if (CTFGame(Level.Game) != None){
    LastScorer = Goals[Goals.Length-1].Scorer.PlayerName;
  }
  matchinfo = TodayHourServerMap();

    // Quick cascade sort.
  for (i=0;i<GRI.PRIArray.Length;i++)
  {
    PRI = GRI.PRIArray[i];

    PRIs.Length = PRIs.Length+1;
    for (j=0;j<Pris.Length-1;j++)
    {
      if (PRIs[j].Score < PRI.Score ||
           (PRIs[j].Score == PRI.Score && PRIs[j].Deaths > PRI.Deaths)
      )
      {
        t = PRIs[j];
        PRIs[j] = PRI;
        PRI = t;
      }
    }
    PRIs[j] = PRI;
  }

  for (i = 0; i < PRIs.Length; i++){
    if (PRIs[i].bOnlySpectator){
      PRIs.Remove(i, 1);
      i = i - 1;
    }
  }

  // Populating the end-game tables
  if (Level.Game.bTeamGame){
	for (i = 0; i<PRIs.Length; i++){
      if (PRIs[i].Team.TeamIndex == 0){
        if ( PRIs[i].PlayerName != "WebAdmin" || !PRIs[i].bOnlySpectator && !PRIs[i].bIsSpectator){
            RedPlayers = RedPlayers$PRIs[i].PlayerName$"%";
            RedScores = RedScores$int(PRIs[i].Score)$"%";
			RedCaptures = RedCaptures$PRIs[i].GoalsScored$"%";
			RedEff = RedEff$Max(PRIs[i].Kills/Min(PRIs[i].Deaths,1),0)$"%";
			if (ASGameInfo(Level.Game) != None){
   			   RedObjectives = RedObjectives$ASPlayerReplicationInfo(PRIs[i]).DisabledObjectivesCount$"%";
			}
        }
	  }
	  else if (PRIs[i].Team.TeamIndex == 1){
        if ( PRIs[i].PlayerName != "WebAdmin" || !PRIs[i].bOnlySpectator && !PRIs[i].bIsSpectator){
            BluePlayers = BluePlayers$PRIs[i].PlayerName$"%";
            BlueScores = BlueScores$int(PRIs[i].Score)$"%";
			BlueCaptures = BlueCaptures$PRIs[i].GoalsScored$"%";
			BlueEff = BlueEff$Max(PRIs[i].Kills/Min(PRIs[i].Deaths,1),0)$"%";
			if (ASGameInfo(Level.Game) != None){
   			   BlueObjectives = BlueObjectives$ASPlayerReplicationInfo(PRIs[i]).DisabledObjectivesCount$"%";
			}
        }
      }
	}

	if(CTFGame(Level.Game) != None && bPostCapSummary){
		for (i=0; i < Goals.Length; i++){
			if (Goals[i].FirstAssistant == Goals[i].Scorer)
				Goals[i].FirstAssistant = None;
			if (Goals[i].SecondAssistant == Goals[i].Scorer)
				Goals[i].SecondAssistant = None;
			if (Goals[i].FirstAssistant != None && Goals[i].SecondAssistant != None){
				Scorers = Scorers$Goals[i].Timestamp$" **"$Goals[i].CurrentScore$"** "$Goals[i].Scorer.PlayerName$" ("$Goals[i].FirstAssistant.PlayerName$", "$Goals[i].SecondAssistant.PlayerName$")%";
			}
			else if (Goals[i].FirstAssistant != None){
				Scorers = Scorers$Goals[i].Timestamp$" **"$Goals[i].CurrentScore$"** "$Goals[i].Scorer.PlayerName$" ("$Goals[i].FirstAssistant.PlayerName$")%";
			}
			else if (Goals[i].SecondAssistant != None){
				Scorers = Scorers$Goals[i].Timestamp$" **"$Goals[i].CurrentScore$"** "$Goals[i].Scorer.PlayerName$" ("$Goals[i].SecondAssistant.PlayerName$")%";
			}
			else{
				Scorers = Scorers$Goals[i].Timestamp$" **"$Goals[i].CurrentScore$"** "$Goals[i].Scorer.PlayerName$" (Unassisted)%";
			}
		}
	}

	RedScoreAttempts = int(myTeams[0].thisTeam.Score)$"/"$myTeams[0].TimesTouchedFlag$"  ("$GetPercentage(myTeams[0].thisTeam.Score, float(myTeams[0].TimesTouchedFlag))$")";
	BlueScoreAttempts = int(myTeams[1].thisTeam.Score)$"/"$myTeams[1].TimesTouchedFlag$"  ("$GetPercentage(myTeams[1].thisTeam.Score, float(myTeams[1].TimesTouchedFlag))$")";
    if (CTFGame(Level.Game)!= None ){
	  Heading = CreateHeading(LastScorer);
	}
	ThreeStars = GetThreeStars();
	FinalScore = int(myTeams[0].thisTeam.Score)$":"$int(myTeams[1].thisTeam.Score);
	if (bOverTime){
	   FinalScore = FinalScore$" OT";
	}

    if (ASGameInfo(Level.Game) != None && bPostObjSummary){
    Log("[DiscordLink] Compiling objective summary:");
 	for (i=0; i<ASObjectives.Length; i++){
 	    Log("[DiscordLink] Compiling objective summary:"@ASObjectives[i].ObjDescription@ASObjectives[i].RedTime$"/"$ASObjectives[i].BlueTime);
        Objectives = Objectives$ASObjectives[i].ObjDescription$"%";
        RedTimes =  RedTimes$ASObjectives[i].RedTime$"%";
        BlueTimes = BlueTimes$ASObjectives[i].BlueTime$"%";

    }
  }

  }
  else{ // not a Teamgame
    for (i = 0; i<PRIs.Length; i++){
      if ( PRIs[i].PlayerName != "WebAdmin" && !PRIs[i].bOnlySpectator ){
          RedPlayers = RedPlayers$PRIs[i].PlayerName$"%";
          RedScores = RedScores$PRIs[i].Kills$"%";
		  RedEff = RedEff$(PRIs[i].Kills/Min(PRIs[i].Deaths,1))$"%";
      }
    }
  }


  if(CTFGame(Level.Game) != None){
	Log("[DiscordLink] Sending CTF Summary");
	if (bPostCapSummary)
		DRP.SendMSG("CTFES"$Rand(1000)$";"$Winners.TeamIndex$";"$FinalScore$";"$Heading$";"$ThreeStars$";"$RedScoreAttempts$";"$BlueScoreAttempts$";"$RedPlayers$";"$BluePlayers$";"$RedScores$";"$BlueScores$";"$RedCaptures$";"$BlueCaptures$";"$matchinfo$";"$Scorers);
	else
		DRP.SendMSG("CTFES"$Rand(1000)$";"$Winners.TeamIndex$";"$FinalScore$";"$Heading$";"$ThreeStars$";"$RedScoreAttempts$";"$BlueScoreAttempts$";"$RedPlayers$";"$BluePlayers$";"$RedScores$";"$BlueScores$";"$RedCaptures$";"$BlueCaptures$";"$matchinfo);
	return;
  }

  if(ASGameInfo(Level.Game) != None){
	Log("[DiscordLink] Sending AS Summary");
	if (bPostObjSummary)
		DRP.SendMSG("ASMES"$Rand(1000)$";"$Winners.TeamIndex$";"$FinalScore$";"$ThreeStars$";"$RedPlayers$";"$BluePlayers$";"$RedScores$";"$BlueScores$";"$RedObjectives$";"$BlueObjectives$";"$matchinfo$";"$Winners.TeamName@"wins the match!"$";"$Objectives$";"$RedTimes$";"$BlueTimes);
//		DRP.SendMSG("ASMES"$Rand(1000)$";"$Winners.TeamIndex$";"$FinalScore$";"$ThreeStars$";"$RedPlayers$";"$BluePlayers$";"$RedScores$";"$BlueScores$";"$RedEff$";"$BlueEff$";"$matchinfo$";"$ASGRI.GetRoundWinnerString());
	else
	DRP.SendMSG("ASMES"$Rand(1000)$";"$Winners.TeamIndex$";"$FinalScore$";"$ThreeStars$";"$RedPlayers$";"$BluePlayers$";"$RedScores$";"$BlueScores$";"$RedObjectives$";"$BlueObjectives$";"$matchinfo$";"$Winners.TeamName@"wins the match!");
	return;
  }


  if (xBombingRun(Level.Game) != None){
  	Log("[DiscordLink] Sending BR Summary");
    DRP.SendMSG("BRMES"$Rand(1000)$";"$Winners.TeamIndex$";"$FinalScore$";"$ThreeStars$";"$RedPlayers$";"$BluePlayers$";"$RedScores$";"$BlueScores$";"$RedCaptures$";"$BlueCaptures$";"$matchinfo);
	return;
  }

  if (Level.Game.bTeamGame){
    Log("[DiscordLink] Sending generic team game Summary");
    DRP.SendMSG("TDMES"$Rand(1000)$";"$Winners.TeamIndex$";"$FinalScore$";"$RedPlayers$";"$BluePlayers$";"$RedScores$";"$BlueScores$";"$RedEff$";"$BlueEff$";"$matchinfo);
	return;
  }

  if(xDeathmatch(Level.Game) != None){
    Log("[DiscordLink] Sending generic team game Summary");
	DRP.SendMSG("DMMES"$Rand(1000)$";"$PRIs[0].PlayerName$";"$RedPlayers$";"$RedScores$";"$RedEff$";"$matchinfo);
	return;
  }



}

event Destroyed()
{
	Super.Destroyed();
}

DefaultProperties
{
// %w - winning team name
// %l - losing team name
// %c - point name ("capture" actually)
// %p - player who made the last capture of the game, last overall, not last for the winning teaam!
// %o - total score (f.e. if game score was 3:1 thi will be replaced by 4)
// type - type of heading, defines situation when this heading should be used
// The available values for type are:
// 0 - shutout victory (a big score shut-out victory f.e. 7-0 or 5-0)
// 1 - solid (3 point difference - 6-2, 4-1 and so on )
// 2 - close score (1 point difference)
// 3 - comeback (was losing but took the lead and won) not implemented yet;
// 4 - overtime win
// 5 - comeback OT victory (managed to tie the match and win the overtime) not implemented yet;
// 6 - any other victory
// 7 - tie
// 8 - 0:0 tie
// 9 - big score match (9:5 and so on, losing team must score more at least 5 goals for this to be used)
  HeadingsArray(0)=(Heading="%w shuts out %l",type=0)
  HeadingsArray(1)=(Heading="%l suffers humiliating defeat from %w",type=0)
  HeadingsArray(2)=(Heading="%l was just no match for %w",type=0)
  HeadingsArray(3)=(Heading="%l is held scoreless by %w",type=0)
  HeadingsArray(4)=(Heading="%w wins against %l with a hefty lead",type=1)
  HeadingsArray(5)=(Heading="%w defeats %l",type=1)
  HeadingsArray(6)=(Heading="%w defeats %l in a close game",type=2)
  HeadingsArray(7)=(Heading="%w wins it by a single %c",type=2)
  HeadingsArray(8)=(Heading="%w wins in OT decider",type=4)
  HeadingsArray(9)=(Heading="%w defeats the %l in OT",type=4)
  HeadingsArray(10)=(Heading="%w defeats %l",type=6)
  HeadingsArray(11)=(Heading="%w stops %l",type=6)
  HeadingsArray(13)=(Heading="%l loses to %w",type=6)
  HeadingsArray(12)=(Heading="%w wins match against %l",type=6)
  HeadingsArray(14)=(Heading="%w edges %l out by one %c",type=2)
  HeadingsArray(15)=(Heading="%w gets a W over %l",type=2)
  HeadingsArray(16)=(Heading="%w comes out on top by a single %c",type=2)
  HeadingsArray(17)=(Heading="Both teams unable to score",type=8)
  HeadingsArray(18)=(Heading="%w and %l find no winner",type=7)
  HeadingsArray(19)=(Heading="%w and %l stay scoreless",type=8)
  HeadingsArray(20)=(Heading="%p brings %w a victory in OT",type=4)
  HeadingsArray(21)=(Heading="It's a draw!",type=7)
  HeadingsArray(22)=(Heading="%p's %c brings %w a victory over %l in OT",type=4)
  HeadingsArray(23)=(Heading="Scoring galore: %o %ps as %w comes out on top",type=9)
  HeadingsArray(24)=(Heading="What's 'defence'? %w wins, teams cap %o flags combined",type=9)
  HeadingsArray(25)=(Heading="%w takes the W in a game with no defence",type=9)
  HeadingsArray(26)=(Heading="%w comes out on top in an all-out game",type=9)
  HeadingsArray(27)=(Heading="%w walks over %l",type=0)
  HeadingsArray(28)=(Heading="%w pounds %l",type=0)
  HeadingsArray(29)=(Heading="%w secures the W with a cap in overtime",type=4)
  HeadingsArray(30)=(Heading="%p leads %w to victory in OT",type=4)
  HeadingsArray(31)=(Heading="%w overpowers %l",type=2)
  HeadingsArray(32)=(Heading="%l was unable to stop %w",type=0)
  HeadingsArray(33)=(Heading="%w tops %l",type=6)
  HeadingsArray(34)=(Heading="%w edges %l in OT",type=4)
  DescString(0)="Enable OLStats passthrough"
  DescString(1)="Report match start event"
  DescString(2)="Report scoring events"
  DescString(3)="Post scoring summary for CTF"
  DescString(4)="Report Sprees/Streaks"
  DescString(5)="Enable flavor headings for CTF/BR match reports"
  bPostCapSummary=True
  bPostObjSummary=True
  bReportMatchStart=True
  bReportScoreEvents=True
  bReportSpreesStreaks=True
  bOLStatsEnabled=True
  Priv=1
}
