//=============================================================================
// BufferedTcpLink: ring-buffered outbound communication over TCP socket.
// Adapted from Unreal Engine 2 source code by fluudah (tuokri on GitHub).
// Copyright Epic Games, Inc. All Rights Reserved.
//=============================================================================
class TKLBufferedTcpLink extends TcpLink;

var byte            OutputBuffer[2048];


var int             OutputBufferHead;
var int             OutputBufferTail;

var string          OutputQueue;
var int             OutputQueueLen;

var bool            bAcceptNewData;

var string          LF;

function PreBeginPlay()
{
    ResetBuffer();
    super.PreBeginPlay();
}

final function ResetBuffer()
{
    OutputQueueLen = 0;
    OutputBufferHead = 0;
    OutputBufferTail = 0;
    LF = Chr(10);
    bAcceptNewData = True;
    LinkMode = Mode_Text;
    ReceiveMode = RMODE_Manual;
}


final function bool SendEOF()
{
    local int NewTail;

    NewTail = OutputBufferTail;
    NewTail = (NewTail + 1) % 2048;
    if (NewTail == OutputBufferHead)
    {
        log("[BufferedTcpLink]: output buffer overrun");
        return False;
    }
    OutputBuffer[OutputBufferTail] = 0;
    OutputBufferTail = NewTail;

    return True;
}

function bool SendBufferedData(string Text)
{
    local int TextLen;
    local int i;
    local int NewTail;

    // // log("Sending: " $ Text $ ".");
	log("Sending: " $ Text $ ".");

    if (!bAcceptNewData)
    {
        return False;
    }

    TextLen = Len(Text);
    for (i = 0; i < TextLen; i++)
    {
        NewTail = OutputBufferTail;
        NewTail = (NewTail + 1) % 2048;
        if (NewTail == OutputBufferHead)
        {
            log("[BufferedTcpLink]: output buffer overrun");
            return False;
        }
        OutputBuffer[OutputBufferTail] = Asc(Mid(Text, i, 1));
        OutputBufferTail = NewTail;
    }

    return True;
}

// DoQueueIO is intended to be called from Tick().
final function DoBufferQueueIO()
{
    local int NewHead;
	local int BytesSent;

    if (IsConnected())
    {
        OutputQueueLen = 0;
        OutputQueue = "";
        NewHead = OutputBufferHead;
        while ((OutputQueueLen < 2048) && (NewHead != OutputBufferTail))
        {
            OutputQueue $= Chr(OutputBuffer[NewHead]);
            OutputQueueLen++;
            NewHead = (NewHead + 1) % 2048;
        }

        if (OutputQueueLen > 0)
        {
            BytesSent = SendText(OutputQueue);
            SendText(OutputQueue);
            OutputBufferHead = NewHead; // (OutputBufferHead + BytesSent) % 2048;
            log("Sent " $ BytesSent $ " bytes >>" $ OutputQueue $ "<<");
        }
    }
}

function bool Close()
{
    SendEOF();
    bAcceptNewData = False;
    return super.Close();
}

defaultproperties
{
   
}
