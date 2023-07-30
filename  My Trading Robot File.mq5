//+------------------------------------------------------------------+
//|                                            Spartan BoomCrash.mq5 |
//|                    Copyright 2022, MetaQuotes Ltd.Ehizojie Lucky |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#define ACCOUNT 0
datetime expiry = D'2050.12.31';

#include <Trade/Trade.mqh>
enum enTrade
  {
   d0 = 0,//Trade Both Buy/Sell
   d1 = 1,//Trade Buy Only
   d2 = 2//Trade Sell Only
  };

//---  INPUTS
input string        str1 = " =<<<======== EA SETTINGS ========>>>=";//_________________
input enTrade             modet = 0;//Trade Mode
input bool                cRever= true;//Close on Reverse Signal
input double              olots = 0.1;//LotSizes
input int                 TP    = 0;//TakeProfit Points "0" is Disable
input int                 SL    = 0;//Stoploss Points "0" is Disable
input int                 Slip = 30;//Slippage for Forex < 5
input string              oComment = "Spartan_";//Order Comment
input int                 oMagic = 563856;//Magic Number
input string         str3  = "=<<=== Trailing Settings ===>>=";//_______________
input bool                Trailing=false;//Use Trailing Stop
input int                 TrailingStop=200;//Trailing Stop
input int                 TrailingStep=30;//Trailing Step
input string        str2 = " =<<<======== MA SETTINGS ========>>>=";//_________________
input bool                UseMAFilt= true;//Use MA Filter
input int                 MaPeriod = 200;//Period
input ENUM_MA_METHOD      MaMethod = 0;//Method
input ENUM_APPLIED_PRICE  MaPrice  = PRICE_CLOSE;//Applied Price

ulong tick;
int Slippage,hMA,hSpart;
double ask,bid,MINLOTSIZE, MAXLOTSIZE;
double MA[],Spartb[],Sparts[];
CTrade mytrade;
datetime LsSignal;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(AccountInfoInteger(ACCOUNT_LOGIN)!=ACCOUNT)
      return(INIT_FAILED);
   if(TimeCurrent()>expiry)
      return(INIT_FAILED);
   Slippage = Slip;
   LsSignal = 0;
   if(_Digits == 3 || _Digits == 5)
      Slippage *= 10;
   ArraySetAsSeries(MA, true);
   ArraySetAsSeries(Spartb, true);
   ArraySetAsSeries(Sparts, true);
   ArrayResize(MA,5);
   ArrayResize(Spartb,5);
   ArrayResize(Sparts,5);
   MINLOTSIZE = (double) SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   MAXLOTSIZE = (double) SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   hMA =iMA(_Symbol,_Period,MaPeriod,0,MaMethod, MaPrice);
   hSpart =iCustom(_Symbol,_Period,"300_SPARTAN",false);
   if(hSpart==INVALID_HANDLE)
      Print(" Failed to get handle of the 300_SPARTAN");
   mytrade.SetExpertMagicNumber(oMagic);
   mytrade.SetDeviationInPoints(Slippage);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   bool nBar = nBar();
   tick = -1;
   int TB = 0, TS = 0;
   bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double stop_=0,take_=0;
   for(int cnt=0; cnt<PositionsTotal(); cnt++)
     {
      tick=PositionGetTicket(cnt);
      if(PositionGetInteger(POSITION_MAGIC)==oMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)
        {
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
            TB++;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            TS++;
        }
     }
   if(nBar)
     {
      int signal = retSignal();
      if(TB <= 0 && (modet==0||modet==1) && signal == 1)
        {
         if(cRever)
            close(1);
         if(TP > 0)
            take_ = NormalizeDouble(ask + TP * _Point,_Digits);
         if(SL > 0)
            stop_ = NormalizeDouble(ask - SL * _Point,_Digits);
         mytrade.Buy(NormalizeDouble(olots,2),_Symbol,ask,stop_,take_,oComment);
         return;
        }
      if(TS <= 0 && (modet==0||modet==2) && signal == -1)
        {
         if(cRever)
            close(0);
         if(TP > 0)
            take_ = NormalizeDouble(bid - TP * _Point,_Digits);
         if(SL > 0)
            stop_ = NormalizeDouble(bid + SL * _Point,_Digits);
         mytrade.Sell(NormalizeDouble(olots,2),_Symbol,bid,stop_,take_,oComment);
         return;
        }
     }
   Trail();
  }
//+------------------------------------------------------------------+
int retSignal()
  {
   ArrayInitialize(MA,0);
   ArrayInitialize(Spartb,0);
   ArrayInitialize(Sparts,0);
   CopyBuffer(hMA,0,0,5,MA);
   CopyBuffer(hSpart,0,0,5,Spartb);
   CopyBuffer(hSpart,1,0,5,Sparts);
   for(int i = 0; i < 5; i++)
     {
      if(LsSignal!=0&&iTime(_Symbol,_Period,i)<=LsSignal)
         return(0);
      if(!UseMAFilt||(iClose(_Symbol,_Period,i)>=MA[i]&&ask>=MA[0]))
         if(Spartb[i]>0&&(Sparts[i]<=0||Sparts[i]==EMPTY_VALUE))
           {
            LsSignal = iTime(_Symbol,_Period,i);
            return(1);
           }
      if(!UseMAFilt||(iClose(_Symbol,_Period,i)<=MA[i]&&bid<=MA[0]))
         if(Sparts[i]>0&&(Spartb[i]<=0||Spartb[i]==EMPTY_VALUE))
           {
            LsSignal = iTime(_Symbol,_Period,i);
            return(-1);
           }
     }
   return(0);
  }
//+------------------------------------------------------------------+
bool nBar()
  {
   static datetime ct = 0;
   if(ct != iTime(_Symbol,PERIOD_CURRENT,0))
     {
      ct = iTime(_Symbol,PERIOD_CURRENT,0);
      return(true);
     }
   return(false);
  }
//+------------------------------------------------------------------+
void close(int type)
  {
   for(int cnt=0; cnt<PositionsTotal(); cnt++)
     {
      tick=PositionGetTicket(cnt);
      if(PositionGetInteger(POSITION_MAGIC)==oMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)
        {
         if(type==0&&PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
            mytrade.PositionClose(PositionGetInteger(POSITION_TICKET),-1);
         if(type==1&&PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            mytrade.PositionClose(PositionGetInteger(POSITION_TICKET),-1);
        }
     }
  }
//+------------------------------------------------------------------+
void Trail()
  {
   if(!Trailing)
      return;
   for(int cnt=0; cnt<PositionsTotal(); cnt++)
     {
      tick=PositionGetTicket(cnt);
      if(PositionGetInteger(POSITION_MAGIC)==oMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)
        {
         double OPP = PositionGetDouble(POSITION_PRICE_OPEN), OSL = PositionGetDouble(POSITION_SL), NewSL = 0;
         double cPrice = fmax(OPP,OSL);
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY && bid>=cPrice+TrailingStop*Point())
           {
            NewSL=NormalizeDouble(cPrice+TrailingStep*Point(),_Digits);
            if(NewSL>=OPP+15*Point()&&NewSL>OSL)
               mytrade.PositionModify(tick,NewSL,PositionGetDouble(POSITION_TP));
           }
         cPrice = fmin(OPP,OSL);
         if(cPrice<=0)
            cPrice=OPP;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL && ask<cPrice-TrailingStop*Point())
           {
            NewSL=NormalizeDouble(cPrice-TrailingStep*Point(),_Digits);
            if(NewSL<=OPP-15*Point()&&(NewSL<OSL||OSL==0))
               mytrade.PositionModify(tick,NewSL,PositionGetDouble(POSITION_TP));
           }
        }
     }
  }
//+------------------------------------------------------------------+
