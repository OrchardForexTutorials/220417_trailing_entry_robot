/*

   Trailing Entry
   Expert

   Copyright 2022, Orchard Forex
   https://www.orchardforex.com

*/

/**=
 *
 * Disclaimer and Licence
 *
 * This file is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * All trading involves risk. You should have received the risk warnings
 * and terms of use in the README.MD file distributed with this software.
 * See the README.MD file for more information and before using this software.
 *
 **/
#include "Framework.mqh"

class CExpert : public CExpertBase {

private:
protected:
   double mTrailAmount;
   double mTPAmount;

   ulong  mBuyTicket;
   ulong  mSellTicket;

   double mBuyPrice;
   double mSellPrice;

   void   CheckTicket( ulong &ticket, double &price, string name );
   void   GetOpenTickets();
   bool   OpenTrade( ENUM_ORDER_TYPE type, double price );
   bool   CloseTrade( ulong ticket );
   void   SetBuyPrice( double price );
   void   SetSellPrice( double price );
   void   SetPriceLine( double price, string name );

   void   Loop();

public:
   CExpert( int trailPoints, int tpPoints,                //
            double volume, string tradeComment, int magic //
   );
   ~CExpert();
};

//
CExpert::CExpert( int trailPoints, int tpPoints,                //
                  double volume, string tradeComment, int magic //
                  )
   : CExpertBase( volume, tradeComment, magic ) {

   // Capture the inputs to member variables
   mTrailAmount = PointsToDouble( trailPoints ); // PointsToDouble is a framework function
   mTPAmount    = PointsToDouble( tpPoints );

   SetBuyPrice( 0 );  // I could just set mBuyPrice=0 but for the demo
   SetSellPrice( 0 ); // I wanted to show these on screen

   // GetOpenTickets is in case of a restart
   // Not foolproof, assumes that there will only ever be one open trade
   // As long as the expert runs normally that will be true but things
   // can go wrong.
   GetOpenTickets();

   mInitResult = INIT_SUCCEEDED; // mInitResult is a framework variable, used to return OnInit
}

//
CExpert::~CExpert() {
}

//
void CExpert::Loop() {

   // This one runs every tick - no need for NewBar

   // Get the current bid and ask
   double bid       = SymbolInfoDouble( mSymbol, SYMBOL_BID );
   double ask       = SymbolInfoDouble( mSymbol, SYMBOL_ASK );

   // These lines just save making the following code look cumbersome
   double buyTrail  = ask + mTrailAmount;
   double sellTrail = bid - mTrailAmount;

   // Update the trailing entry prices
   if ( ( mBuyPrice == 0 || mBuyPrice > buyTrail ) && mBuyTicket == 0 ) SetBuyPrice( buyTrail );
   if ( ( mSellPrice == 0 || mSellPrice < sellTrail ) && mSellTicket == 0 )
      SetSellPrice( sellTrail );

   // What if a ticket has hit tp
   //		It will have been closed by the broker, how to check
   if ( mBuyTicket > 0 ) CheckTicket( mBuyTicket, mBuyPrice, "Buy" );
   if ( mSellTicket > 0 ) CheckTicket( mSellTicket, mSellPrice, "Sell" );

   // Check if a trailing entry price has been hit
   // There is a rare chance here that both buy and sell can be hit at
   //		the same time if the trails are tight and spreads are wide
   if ( mBuyPrice > 0 && mBuyTicket == 0 &&
        ask >= mBuyPrice ) { // There is a trail price, no curent ticket and entry has been hit
      if ( mSellTicket > 0 ) {
         if ( CloseTrade( mSellTicket ) ) {
            mSellTicket = 0;
            SetSellPrice( 0 );
         }
      }
      if ( OpenTrade( ORDER_TYPE_BUY, ask ) ) {
         SetBuyPrice( 0 );
      }
   }
   if ( mSellPrice > 0 && mSellTicket == 0 &&
        bid <= mSellPrice ) { // There is a trail price, no curent ticket and entry has been hit
      if ( mBuyTicket > 0 ) {
         if ( CloseTrade( mBuyTicket ) ) {
            mBuyTicket = 0;
            SetBuyPrice( 0 );
         }
      }
      if ( OpenTrade( ORDER_TYPE_SELL, bid ) ) {
         SetSellPrice( 0 );
      }
   }

   return;
}

bool CExpert::OpenTrade( ENUM_ORDER_TYPE type, double price ) {

   double tp = ( type == ORDER_TYPE_BUY ) ? price + mTPAmount : price - mTPAmount;
   if ( Trade.PositionOpen( mSymbol, type, mOrderSize, price, 0, tp, mTradeComment ) ) {
      GetOpenTickets();
      return ( true );
   }
   return ( false );
}

bool CExpert::CloseTrade( ulong ticket ) {

   return ( Trade.PositionClose( ticket ) );
}

void CExpert::SetBuyPrice( double price ) {

   mBuyPrice = price;
   SetPriceLine( price, "Buy" );
}

void CExpert::SetSellPrice( double price ) {

   mSellPrice = price;
   SetPriceLine( price, "Sell" );
}

void CExpert::SetPriceLine( double price, string name ) {

   string textName = name + "_text";
   ObjectDelete( 0, name );
   ObjectDelete( 0, textName );
   ChartRedraw( 0 );

   if ( price == 0 ) return;

   datetime time0 = iTime( mSymbol, mTimeframe, 0 );
   datetime time1 = iTime( mSymbol, mTimeframe, 1 );

   ObjectCreate( 0, name, OBJ_TREND, 0, time1, price, time0, price );
   ObjectSetInteger( 0, name, OBJPROP_HIDDEN, false );
   ObjectSetInteger( 0, name, OBJPROP_RAY_RIGHT, true );
   ObjectSetInteger( 0, name, OBJPROP_COLOR, clrYellow );

   ObjectCreate( 0, textName, OBJ_TEXT, 0, time0, price );
   ObjectSetInteger( 0, textName, OBJPROP_HIDDEN, false );
   ObjectSetString( 0, textName, OBJPROP_TEXT, StringFormat( name + " %f", price ) );
   ObjectSetInteger( 0, textName, OBJPROP_COLOR, clrYellow );

   return;
}

//
//	Some specific MT4/MT5 code
//
#ifdef __MQL4__

void CExpert::GetOpenTickets() {

   mBuyTicket  = 0;
   mSellTicket = 0;

   for ( int i = OrdersTotal() - 1; i >= 0; i-- ) {
      if ( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) ) {
         if ( OrderMagicNumber() == mMagic && OrderSymbol() == mSymbol ) {
            if ( OrderType() == ORDER_TYPE_BUY ) {
               mBuyTicket = OrderTicket();
            }
            else if ( OrderType() == ORDER_TYPE_SELL ) {
               mSellTicket = OrderTicket();
            }
         }
      }
   }
}

void CExpert::CheckTicket( ulong &ticket, double &price, string name ) {

   if ( ticket > 0 ) {
      if ( !OrderSelect( ( int )ticket, SELECT_BY_TICKET ) || ( OrderCloseTime() > 0 ) ) {
         ticket = 0;
         price  = 0;
         SetPriceLine( price, name );
      }
   }
}

#endif

#ifdef __MQL5__

void CExpert::GetOpenTickets() {

   mBuyTicket  = 0;
   mSellTicket = 0;

   for ( int i = PositionsTotal() - 1; i >= 0; i-- ) {
      if ( PositionInfo.SelectByIndex( i ) ) {
         if ( PositionInfo.Magic() == mMagic && PositionInfo.Symbol() == mSymbol ) {
            if ( PositionInfo.PositionType() == POSITION_TYPE_BUY ) {
               mBuyTicket = PositionInfo.Ticket();
            }
            else if ( PositionInfo.PositionType() == POSITION_TYPE_SELL ) {
               mSellTicket = PositionInfo.Ticket();
            }
         }
      }
   }
}

void CExpert::CheckTicket( ulong &ticket, double &price, string name ) {

   if ( ticket > 0 ) {
      if ( !PositionSelectByTicket( ticket ) ) {
         ticket = 0;
         price  = 0;
         SetPriceLine( price, name );
      }
   }
}

#endif

//
