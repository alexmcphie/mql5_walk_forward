//+------------------------------------------------------------------+
//|                                             Walk Forward Analyis |
//|                                      Copyright 2025, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
/*
have a hard time trying to implement DD into the reports


*/
#property copyright ""
#property link      ""

#define INDEX_PROFIT 2
#define INDEX_PROFIT_FACTOR 26
#define INDEX_TRADES 32
#define INDEX_REL_DD 18  // Assuming this is the correct index for Balance Rel_DD



// below are auto adjusting so i dont know why they need to be inputs
input group "WFA Interal Auto-Adjusting Vars, Don't Touch!"
input int wfa_step_counts=0;
input datetime wfa_begin_is=0;
input datetime wfa_begin_os=0;


input group "Walk Forward Optimization Settings and Statistics"
input bool EnableWFA = true;  // ✅ Toggle WFA on/off
input bool wfa_IS_OSS_Toggle_Switch=false; //wfa_IS_OSS_Toggle_Switch --> MUST be checked to do IS/OSS tests
input datetime opt_start_time=D'2021.01.01 00:00:00';
input datetime opt_end_time=D'2024.11.15 00:00:00';
input int wfa_in_sample_days=300;
input int wfa_out_sample_days=200;
input int wfa_step_days=100;
input int min_trades_threshold=50;  // minimum trades for IS and OS
input double Max_DD = 10.0;  // ✅ New Input: Max acceptable Relative Drawdown (%)

// group "WFA Statistics to track in reports"
// these are the boolean options for which stat i can track, by using this bool i can select or de select all of the STATS that i do or don't want to show in my report.
// if set to true then it will show up in my report.
bool bSTAT_INITIAL_DEPOSIT=false;//STAT_INITIAL_DEPOSIT
bool bSTAT_WITHDRAWAL=false;//STAT_WITHDRAWAL
bool bSTAT_PROFIT=true;//STAT_PROFIT
bool bSTAT_GROSS_PROFIT=false;//STAT_GROSS_PROFIT
bool bSTAT_GROSS_LOSS=false;//STAT_GROSS_LOSS
bool bSTAT_MAX_PROFITTRADE=false;//STAT_MAX_PROFITTRADE
bool bSTAT_MAX_LOSSTRADE=false;//STAT_MAX_LOSSTRADE
bool bSTAT_CONPROFITMAX=false;//STAT_CONPROFITMAX
bool bSTAT_CONPROFITMAX_TRADES=false;//STAT_CONPROFITMAX_TRADES
bool bSTAT_MAX_CONWINS=false;//STAT_MAX_CONWINS
bool bSTAT_MAX_CONPROFIT_TRADES=false;//STAT_MAX_CONPROFIT_TRADES
bool bSTAT_CONLOSSMAX=false;//STAT_CONLOSSMAX
bool bSTAT_CONLOSSMAX_TRADES=false;//STAT_CONLOSSMAX_TRADES
bool bSTAT_MAX_CONLOSSES=false;//STAT_MAX_CONLOSSES
bool bSTAT_MAX_CONLOSS_TRADES=false;//STAT_MAX_CONLOSS_TRADES
bool bSTAT_BALANCEMIN=false;//STAT_BALANCEMIN
bool bSTAT_BALANCE_DD=false;//STAT_BALANCE_DD
bool bSTAT_BALANCEDD_PERCENT=false;//STAT_BALANCEDD_PERCENT
bool bSTAT_BALANCE_DDREL_PERCENT=true;//STAT_BALANCE_DDREL_PERCENT
bool bSTAT_BALANCE_DD_RELATIVE=false;//STAT_BALANCE_DD_RELATIVE
bool bSTAT_EQUITYMIN=false;//STAT_EQUITYMIN
bool bSTAT_EQUITY_DD=false;//STAT_EQUITY_DD
bool bSTAT_EQUITYDD_PERCENT=false;//STAT_EQUITYDD_PERCENT
bool bSTAT_EQUITY_DDREL_PERCENT=true;//STAT_EQUITY_DDREL_PERCENT
bool bSTAT_EQUITY_DD_RELATIVE=false;//STAT_EQUITY_DD_RELATIVE
bool bSTAT_EXPECTED_PAYOFF=false;//STAT_EXPECTED_PAYOFF
bool bSTAT_PROFIT_FACTOR=true;//STAT_PROFIT_FACTOR
bool bSTAT_RECOVERY_FACTOR=false;//STAT_RECOVERY_FACTOR
bool bSTAT_SHARPE_RATIO=false;//STAT_SHARPE_RATIO
bool bSTAT_MIN_MARGINLEVEL=false;//STAT_MIN_MARGINLEVEL
bool bSTAT_CUSTOM_ONTESTER=true;//STAT_CUSTOM_ONTESTER
bool bSTAT_DEALS=false;//STAT_DEALS
bool bSTAT_TRADES=true;//STAT_TRADES
bool bSTAT_PROFIT_TRADES=false;//STAT_PROFIT_TRADES
bool bSTAT_LOSS_TRADES=false;//STAT_LOSS_TRADES
bool bSTAT_SHORT_TRADES=false;//STAT_SHORT_TRADES
bool bSTAT_LONG_TRADES=false;//STAT_LONG_TRADES
bool bSTAT_PROFIT_SHORTTRADES=false;//STAT_PROFIT_SHORTTRADES
bool bSTAT_PROFIT_LONGTRADES=false;//STAT_PROFIT_LONGTRADES
bool bSTAT_PROFITTRADES_AVGCON=false;//STAT_PROFITTRADES_AVGCON
bool bSTAT_LOSSTRADES_AVGCON=false;//STAT_LOSSTRADES_AVGCON


input group "Local EA Input Variables For Optimization"


//+------------------------------------------------------------------+
//|                     Structures                                   |
//+------------------------------------------------------------------+
struct OptimizationResult
  {
   string            row_data;     // Complete row data
   double            profit;       // For sorting by profit
   double            sharpe;       // For sorting by Sharpe ratio
   double            profit_factor; // For sorting by profit factor
  };

struct WindowResult
  {
   datetime          start_time;      // Window start time
   datetime          end_time;        // Window end time
   bool              is_insample;        // Is this in-sample or out-of-sample
   double            profit;           // Profit for this window
   double            profit_factor;    // Profit factor for this window
   double            drawdown;         // Maximum drawdown
   double            sharpe;           // Sharpe ratio
   string            parameters;       // Parameter values used
  };

struct ParameterPerformance
  {
   string            name;             // Parameter name
   double            value;           // Parameter value
   double            avg_is_profit;   // Average in-sample profit
   double            avg_os_profit;   // Average out-of-sample profit
   int               success_count;      // Number of successful windows
   double            correlation;     // Correlation between IS and OS performance
  };


//+------------------------------------------------------------------+
//|  A struct to hold the pass results, now with a 'parameters' field|
//+------------------------------------------------------------------+
//struct PassResult
//  {
//   long              pass_number;
//
//   long              is_begin;
//   long              is_end;
//   long              os_begin;
//   long              os_end;
//
//   double            is_profit;
//   double            is_pf;
//   double            os_profit;
//   double            os_pf;
//
//   // NEW: This will store all param name=values for this pass
//   string            parameters;
//
//   long               is_trades;
//   long               os_trades;
//
//   string            window_id;  // New field for unique window identification
//
//  };

//+------------------------------------------------------------------+
//|  A helper struct for the enumerated windows                      |
//+------------------------------------------------------------------+
struct WindowDef
  {
   long              is_begin;
   long              is_end;
   long              os_begin;
   long              os_end;
  };




//
//
//struct CombinedPass
//  {
//   long              pass_number;
//   long              is_begin;
//   long              os_begin;
//   double            is_profit;
//   double            os_profit;
//   double            is_pf;
//   double            os_pf;
//   double            total_profit;   // is_profit + os_profit
//   long              is_trades;      // new
//   long              os_trades;      // new
//   string            parameters;
//
//   string            window_id;
//
//  };


// Update the PassResult struct to include IS and OS Rel_DD
struct PassResult
  {
   long              pass_number;
   long              is_begin, is_end, os_begin, os_end;
   double            is_profit, is_pf, os_profit, os_pf;
   double            is_drawdown, os_drawdown;  // ✅ New: Store IS and OS Rel_DD
   long              is_trades, os_trades;
   string            parameters;
   string            window_id;
  };

struct CombinedPass
  {
   long              pass_number;
   long              is_begin, os_begin;
   double            is_profit, os_profit, is_pf, os_pf, total_profit;
   double            is_drawdown, os_drawdown;  // ✅ New: Store IS and OS Rel_DD
   long              is_trades, os_trades;
   string            parameters;
   string            window_id;
  };


// Global arrays to store results
WindowResult window_results[];
ParameterPerformance param_performance[];

datetime begin_is,end_is,begin_os,end_os;




datetime timebeginos[100000];
int ctimebeginos;
int iwfa_step_counts;
double wfa_data[41];
datetime computed_os_begin = 0;




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool wfa_init()
  {
   if(!EnableWFA)
     {
      Print(__FUNCTION__, ": WFA is disabled, skipping initialization.");
      return true;  // ✅ Return true to prevent initialization failure
     }

   Print(__FUNCTION__, ": Initializing WFA...");
// Continue normal WFA initialization
   computed_os_begin = wfa_begin_os;
   if(computed_os_begin == 0)
      computed_os_begin = wfa_begin_is + (wfa_in_sample_days * 86400);

   begin_is = wfa_begin_is;
   end_is   = wfa_begin_is + (wfa_in_sample_days * 86400);

   begin_os = computed_os_begin;
   end_os   = computed_os_begin + (wfa_out_sample_days * 86400);

   Print(__FUNCTION__,
         ": begin_is=", TimeToString(begin_is),
         ", end_is=",   TimeToString(end_is),
         ", computed_os_begin=", TimeToString(computed_os_begin),
         ", end_os=",   TimeToString(end_os)
        );

   return true;
  }




//+------------------------------------------------------------------+
//| (E) wfa_testerinit: Called once before optimization runs         |
//+------------------------------------------------------------------+
void wfa_testerinit()
  {

   if(!EnableWFA)
     {
      Print(__FUNCTION__, ": WFA is disabled, skipping tester init.");
      return;
     }


   Print(__FUNCTION__, "  Start of wfa_testerinit()");

// 1) Figure out how many windows can fit from opt_start_time to opt_end_time:
   int       stepCount   = 0;
   datetime  curIsBegin  = opt_start_time;

   while(curIsBegin + ((wfa_in_sample_days + wfa_out_sample_days) * 86400) <= opt_end_time)
     {
      stepCount++;
      curIsBegin += (wfa_step_days * 86400);
     }
   iwfa_step_counts = stepCount;

   Print("We can fit ", stepCount,
         " full windows of (", wfa_in_sample_days, " IS + ",
         wfa_out_sample_days, " OS) stepping by ", wfa_step_days, " days.");

// 2) Let MetaTrader know not to enumerate wfa_step_counts or wfa_begin_os
   ParameterSetRange("wfa_step_counts", false, 0,0,1, iwfa_step_counts);
   ParameterSetRange("wfa_begin_os",   false, 0,0,1, 0);  // fixed, not enumerated

// 3) Enumerate only wfa_begin_is (and the boolean toggle)
   ParameterSetRange("wfa_begin_is",
                     true,                      // enumerated
                     opt_start_time,            // start
                     opt_start_time,            // min
                     (wfa_step_days * 86400),   // step
                     opt_start_time + (stepCount * wfa_step_days * 86400)  // max
                    );

   ParameterSetRange("wfa_IS_OSS_Toggle_Switch",
                     true,       // enumerated
                     false,      // start
                     false,      // min
                     1,          // step
                     true        // max
                    );

   Print(__FUNCTION__, "  End of wfa_testerinit(), error code: ", GetLastError());
  }





//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool wfa_ontick()
  {
   if(!EnableWFA)
     {
      return true;  // ✅ If disabled, allow trades normally
     }

// Normal WFA logic follows
   if(TimeCurrent() >= begin_is && TimeCurrent() < end_is && wfa_IS_OSS_Toggle_Switch == false)
     {
      Print(__FUNCTION__, " => In-Sample pass returning true.");
      return true;
     }

   if(TimeCurrent() >= begin_os && TimeCurrent() < end_os && wfa_IS_OSS_Toggle_Switch == true)
     {
      Print(__FUNCTION__, " => Out-of-Sample pass returning true.");
      return true;
     }

   return false;  // ✅ Block trades if outside IS/OS range
  }




void wfa_ontester()
{
   if(!EnableWFA)
   {
      Print(__FUNCTION__, ": WFA is disabled, skipping tester logic.");
      return;
   }

   // First get the parameter string
   string paramStr = f_param_string();

   // Generate window ID
   string window_id = GenerateWindowID(wfa_begin_is, paramStr);

   // Store test statistics
   wfa_data[INDEX_PROFIT] = TesterStatistics(STAT_PROFIT);
   wfa_data[INDEX_PROFIT_FACTOR] = TesterStatistics(STAT_PROFIT_FACTOR);
   wfa_data[INDEX_TRADES] = TesterStatistics(STAT_TRADES);
   wfa_data[INDEX_REL_DD] = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);  // ✅ Ensure correct index

   // Debugging prints to check values
   Print("Window ID: ", window_id, " | Profit: ", wfa_data[INDEX_PROFIT],
         " | Trades: ", wfa_data[INDEX_TRADES], " | Rel_DD: ", wfa_data[INDEX_REL_DD]);

   // Determine frame ID based on IS/OS toggle
   int frame_id = (wfa_IS_OSS_Toggle_Switch ? 2 : 1);

   // Generate unique pass number
   string param_id = window_id + "_" + paramStr;
   ulong pass_num = GenerateHash(param_id);

   // Store data in frame
   FrameAdd("WFA", frame_id, pass_num, wfa_data);
}


//+------------------------------------------------------------------+
//| Helper Function: Generate Unique Parameter String                |
//+------------------------------------------------------------------+
string f_param_string()
  {
   string paramString = "";
   string paramArray[];
   uint paramCount;

   if(FrameInputs(0, paramArray, paramCount))
     {


      // Retrieve current optimization parameters
      // FrameInputs(0, paramArray, paramCount);

      for(uint i = 0; i < paramCount; i++)
        {
         if(paramString != "")
            paramString += "|";  // Separator for clarity

         paramString += paramArray[i];
        }
     }

   return paramString;
  }

//+------------------------------------------------------------------+
//| Helper Function: Simple Hash Generator for Strings              |
//+------------------------------------------------------------------+
ulong GenerateHash(string str_input)
  {
   ulong hash = 0;
   int len = StringLen(str_input);
   for(int i = 0; i < len; i++)
     {
      hash = (hash * 31) + StringGetCharacter(str_input, i);
     }
   return hash;
  }




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string f_tf()
  {
   if(_Period==PERIOD_M1)
      return "M1";
   if(_Period==PERIOD_M2)
      return "M2";
   if(_Period==PERIOD_M3)
      return "M3";
   if(_Period==PERIOD_M4)
      return "M4";
   if(_Period==PERIOD_M5)
      return "M5";
   if(_Period==PERIOD_M6)
      return "M6";
   if(_Period==PERIOD_M10)
      return "M10";
   if(_Period==PERIOD_M12)
      return "M12";
   if(_Period==PERIOD_M15)
      return "M15";
   if(_Period==PERIOD_M20)
      return "M20";
   if(_Period==PERIOD_M30)
      return "M30";
   if(_Period==PERIOD_H1)
      return "H1";
   if(_Period==PERIOD_H2)
      return "H2";
   if(_Period==PERIOD_H3)
      return "H3";
   if(_Period==PERIOD_H4)
      return "H4";
   if(_Period==PERIOD_H6)
      return "H6";
   if(_Period==PERIOD_H8)
      return "H8";
   if(_Period==PERIOD_H12)
      return "H12";
   if(_Period==PERIOD_D1)
      return "D1";
   if(_Period==PERIOD_W1)
      return "W1";
   if(_Period==PERIOD_MN1)
      return "MN1";
   return "M1";
  }





//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string f_firststr()
  {
   string firststr="";
   if(bSTAT_INITIAL_DEPOSIT)
      firststr=firststr+";"+"STAT_INITIAL_DEPOSIT";
   if(bSTAT_WITHDRAWAL)
      firststr=firststr+";"+"STAT_WITHDRAWAL";
   if(bSTAT_PROFIT)
      firststr=firststr+";"+"STAT_PROFIT";
   if(bSTAT_GROSS_PROFIT)
      firststr=firststr+";"+"STAT_GROSS_PROFIT";
   if(bSTAT_GROSS_LOSS)
      firststr=firststr+";"+"STAT_GROSS_LOSS";
   if(bSTAT_MAX_PROFITTRADE)
      firststr=firststr+";"+"STAT_MAX_PROFITTRADE";
   if(bSTAT_MAX_LOSSTRADE)
      firststr=firststr+";"+"STAT_MAX_LOSSTRADE";
   if(bSTAT_CONPROFITMAX)
      firststr=firststr+";"+"STAT_CONPROFITMAX";
   if(bSTAT_CONPROFITMAX_TRADES)
      firststr=firststr+";"+"STAT_CONPROFITMAX_TRADES";
   if(bSTAT_MAX_CONWINS)
      firststr=firststr+";"+"STAT_MAX_CONWINS";
   if(bSTAT_MAX_CONPROFIT_TRADES)
      firststr=firststr+";"+"STAT_MAX_CONPROFIT_TRADES";
   if(bSTAT_CONLOSSMAX)
      firststr=firststr+";"+"STAT_CONLOSSMAX";
   if(bSTAT_CONLOSSMAX_TRADES)
      firststr=firststr+";"+"STAT_CONLOSSMAX_TRADES";
   if(bSTAT_MAX_CONLOSSES)
      firststr=firststr+";"+"STAT_MAX_CONLOSSES";
   if(bSTAT_MAX_CONLOSS_TRADES)
      firststr=firststr+";"+"STAT_MAX_CONLOSS_TRADES";
   if(bSTAT_BALANCEMIN)
      firststr=firststr+";"+"STAT_BALANCEMIN";
   if(bSTAT_BALANCE_DD)
      firststr=firststr+";"+"STAT_BALANCE_DD";
   if(bSTAT_BALANCEDD_PERCENT)
      firststr=firststr+";"+"STAT_BALANCEDD_PERCENT";
   if(bSTAT_BALANCE_DDREL_PERCENT)
      firststr=firststr+";"+"STAT_BALANCE_DDREL_PERCENT";
   if(bSTAT_BALANCE_DD_RELATIVE)
      firststr=firststr+";"+"STAT_BALANCE_DD_RELATIVE";
   if(bSTAT_EQUITYMIN)
      firststr=firststr+";"+"STAT_EQUITYMIN";
   if(bSTAT_EQUITY_DD)
      firststr=firststr+";"+"STAT_EQUITY_DD";
   if(bSTAT_EQUITYDD_PERCENT)
      firststr=firststr+";"+"STAT_EQUITYDD_PERCENT";
   if(bSTAT_EQUITY_DDREL_PERCENT)
      firststr=firststr+";"+"STAT_EQUITY_DDREL_PERCENT";
   if(bSTAT_EQUITY_DD_RELATIVE)
      firststr=firststr+";"+"STAT_EQUITY_DD_RELATIVE";
   if(bSTAT_EXPECTED_PAYOFF)
      firststr=firststr+";"+"STAT_EXPECTED_PAYOFF";
   if(bSTAT_PROFIT_FACTOR)
      firststr=firststr+";"+"STAT_PROFIT_FACTOR";
   if(bSTAT_RECOVERY_FACTOR)
      firststr=firststr+";"+"STAT_RECOVERY_FACTOR";
   if(bSTAT_SHARPE_RATIO)
      firststr=firststr+";"+"STAT_SHARPE_RATIO";
   if(bSTAT_MIN_MARGINLEVEL)
      firststr=firststr+";"+"STAT_MIN_MARGINLEVEL";
   if(bSTAT_CUSTOM_ONTESTER)
      firststr=firststr+";"+"STAT_CUSTOM_ONTESTER";
   if(bSTAT_DEALS)
      firststr=firststr+";"+"STAT_DEALS";
   if(bSTAT_TRADES)
      firststr=firststr+";"+"STAT_TRADES";
   if(bSTAT_PROFIT_TRADES)
      firststr=firststr+";"+"STAT_PROFIT_TRADES";
   if(bSTAT_LOSS_TRADES)
      firststr=firststr+";"+"STAT_LOSS_TRADES";
   if(bSTAT_SHORT_TRADES)
      firststr=firststr+";"+"STAT_SHORT_TRADES";
   if(bSTAT_LONG_TRADES)
      firststr=firststr+";"+"STAT_LONG_TRADES";
   if(bSTAT_PROFIT_SHORTTRADES)
      firststr=firststr+";"+"STAT_PROFIT_SHORTTRADES";
   if(bSTAT_PROFIT_LONGTRADES)
      firststr=firststr+";"+"STAT_PROFIT_LONGTRADES";
   if(bSTAT_PROFITTRADES_AVGCON)
      firststr=firststr+";"+"STAT_PROFITTRADES_AVGCON";
   if(bSTAT_LOSSTRADES_AVGCON)
      firststr=firststr+";"+"STAT_LOSSTRADES_AVGCON";
   return firststr;
  }





// Custom comparison function for sorting
int CompareByProfit(const OptimizationResult &a, const OptimizationResult &b)
  {
   if(a.profit > b.profit)
      return -1;  // Descending order
   if(a.profit < b.profit)
      return 1;
   return 0;
  }

// Bubble sort implementation (since MQL5 doesn't allow passing functions to ArraySort)
void BubbleSortResults(OptimizationResult &results[])
  {
   int size = ArraySize(results);
   for(int i = 0; i < size - 1; i++)
     {
      for(int j = 0; j < size - i - 1; j++)
        {
         if(CompareByProfit(results[j], results[j + 1]) > 0)
           {
            OptimizationResult temp = results[j];
            results[j] = results[j + 1];
            results[j + 1] = temp;
           }
        }
     }
  }




// Helper function to search for a string in an array
int FindInArray(const string &arr[], string value)
  {
   for(int i = 0; i < ArraySize(arr); i++)
     {
      if(arr[i] == value)
         return i;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AnalyzeParameterPerformance()
  {
   int windows_count = ArraySize(window_results);
   if(windows_count == 0)
      return;

// First, collect unique parameter combinations
   string unique_params[];
   ArrayResize(unique_params, 0);

   for(int i = 0; i < windows_count; i++)
     {
      string params = window_results[i].parameters;
      if(FindInArray(unique_params, params) == -1)
        {
         int new_size = ArraySize(unique_params) + 1;
         ArrayResize(unique_params, new_size);
         unique_params[new_size - 1] = params;
        }
     }

// Initialize parameter performance array
   ArrayResize(param_performance, ArraySize(unique_params));

// Calculate statistics for each parameter combination
   for(int i = 0; i < ArraySize(unique_params); i++)
     {
      double is_profits[];
      double os_profits[];
      ArrayResize(is_profits, 0);
      ArrayResize(os_profits, 0);

      // Collect profits for this parameter combination
      for(int j = 0; j < windows_count; j++)
        {
         if(window_results[j].parameters == unique_params[i])
           {
            if(window_results[j].is_insample)
              {
               int is_size = ArraySize(is_profits) + 1;
               ArrayResize(is_profits, is_size);
               is_profits[is_size - 1] = window_results[j].profit;
              }
            else
              {
               int os_size = ArraySize(os_profits) + 1;
               ArrayResize(os_profits, os_size);
               os_profits[os_size - 1] = window_results[j].profit;
              }
           }
        }

      // Calculate averages and store results
      param_performance[i].name = unique_params[i];
      param_performance[i].avg_is_profit = ArrayAverage(is_profits);
      param_performance[i].avg_os_profit = ArrayAverage(os_profits);

      // Calculate success rate
      int success_count = 0;
      for(int j = 0; j < ArraySize(os_profits); j++)
        {
         if(os_profits[j] > 0)
            success_count++;
        }
      param_performance[i].success_count = success_count;

      // Calculate correlation between IS and OS results
      param_performance[i].correlation = ArrayCorrelation(is_profits, os_profits);
     }
  }

// Helper function to calculate array average
double ArrayAverage(const double &arr[])
  {
   int size = ArraySize(arr);
   if(size == 0)
      return 0;

   double sum = 0;
   for(int i = 0; i < size; i++)
      sum += arr[i];
   return sum / size;
  }

// Helper function to calculate correlation
double ArrayCorrelation(const double &arr1[], const double &arr2[])
  {
   int size = MathMin(ArraySize(arr1), ArraySize(arr2));
   if(size < 2)
      return 0;

   double sum_x = 0, sum_y = 0, sum_xy = 0;
   double sum_x2 = 0, sum_y2 = 0;

   for(int i = 0; i < size; i++)
     {
      sum_x += arr1[i];
      sum_y += arr2[i];
      sum_xy += arr1[i] * arr2[i];
      sum_x2 += arr1[i] * arr1[i];
      sum_y2 += arr2[i] * arr2[i];
     }

   double numerator = size * sum_xy - sum_x * sum_y;
   double denominator = MathSqrt((size * sum_x2 - sum_x * sum_x) * (size * sum_y2 - sum_y * sum_y));

   if(denominator == 0)
      return 0;
   return numerator / denominator;
  }










//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsParamSelectedForOptimization(const string &pName)
  {
// Local flags and range variables for the "long" overload
   bool   isEnumeratedI = false;
   long   iFrom         = 0,
          iStep         = 0,
          iTo           = 0,
          iCommon       = 0;

// Local flags and range variables for the "double" overload
   bool   isEnumeratedD = false;
   double dFrom         = 0.0,
          dStep         = 0.0,
          dTo           = 0.0,
          dCommon       = 0.0;

   bool foundParam = false; // we'll set to true if either overload succeeds

// --- 1) Try integer version ----------------------------------
   if(ParameterGetRange(pName, isEnumeratedI, iFrom, iStep, iTo, iCommon))
     {
      // This means the param is recognized as a long/int type
      foundParam = true;
      if(!isEnumeratedI)
         return false; // user did not actually check it for optimization
     }
   else
     {
      // --- 2) If that fails, try double version -----------------
      if(ParameterGetRange(pName, isEnumeratedD, dFrom, dStep, dTo, dCommon))
        {
         foundParam = true;
         if(!isEnumeratedD)
            return false; // user did not check it
        }
     }

// If neither overload succeeded, it's not a recognized parameter
   if(!foundParam)
      return false;

// --- 3) Exclude known WFA or internal parameters -------------
// If you have more you want to exclude, just add them here
   if(StringFind(pName, "wfa_") == 0)
      return false;  // e.g. wfa_begin_is, wfa_step_counts, etc.
   if(StringSubstr(pName, 0, 5) == "bSTAT")
      return false;  // bSTAT_ booleans
   if(pName == "min_trades_threshold")
      return false;
   if(pName == "opt_start_time" || pName == "opt_end_time")
      return false;

// If we get here, it was enumerated and not excluded
   return true;
  }




//+------------------------------------------------------------------+
void QuickSort(CombinedPass &arr[], int left, int right)
  {
   if(ArraySize(arr) == 0)
      return; // ✅ Prevent sorting an empty array
   if(left >= right)
      return;       // ✅ Ensure valid indices

   int i = left, j = right;
   int pivotIndex = (left + right) / 2;

// ✅ Ensure pivot index is valid
   if(pivotIndex < 0 || pivotIndex >= ArraySize(arr))
      return;

   double pivot = arr[pivotIndex].total_profit;

   while(i <= j)
     {
      while(i < ArraySize(arr) && arr[i].total_profit > pivot)
         i++;
      while(j >= 0 && arr[j].total_profit < pivot)
         j--;

      if(i <= j)
        {
         CombinedPass temp = arr[i];
         arr[i] = arr[j];
         arr[j] = temp;
         i++;
         j--;
        }
     }

   if(left < j)
      QuickSort(arr, left, j);
   if(i < right)
      QuickSort(arr, i, right);
  }



//+------------------------------------------------------------------+
//| Generate a unique window ID based on time period and parameters    |
//+------------------------------------------------------------------+
string GenerateWindowID(datetime start_time, const string &params)
  {
   return StringFormat("window_%d_%u", start_time, GenerateHash(params));
  }


void wfa_testerdeinit() {
   if (!EnableWFA) {
      Print(__FUNCTION__, ": WFA is disabled, skipping tester deinit.");
      return;
   }

   // Arrays to store IS vs OS results
   PassResult passIS[], passOS[];
   ArrayResize(passIS, 0);
   ArrayResize(passOS, 0);

   string name;
   long id = 0, frame_id = 0;
   double value;

   //======================================================
   // (A) Read In-Sample (IS) Data
   //======================================================
   FrameFirst();
   FrameFilter("WFA", 1);
   
   while (FrameNext(id, name, frame_id, value, wfa_data)) {
      PassResult pr;
      pr.pass_number = id;
      pr.is_begin = (datetime)wfa_begin_is;
      pr.is_end = pr.is_begin + (wfa_in_sample_days * 86400);
      pr.os_begin = pr.is_end;
      pr.os_end = pr.os_begin + (wfa_out_sample_days * 86400);
      
      // Retrieve parameters for this run
      string paramList = "";
      string paramArray[];
      uint paramCount;
      if (FrameInputs(id, paramArray, paramCount)) {
         for (uint k = 0; k < paramCount; k++) {
            string pieces[];
            StringSplit(paramArray[k], '=', pieces);
            if (ArraySize(pieces) < 2) continue;

            string pName = pieces[0];
            string pVal = pieces[1];

            if (IsParamSelectedForOptimization(pName)) {
               if (paramList != "")
                  paramList += " | ";
               paramList += pName + "=" + pVal;
            }
         }
      }
      
      pr.parameters = paramList;
      pr.window_id = GenerateWindowID(pr.is_begin, paramList);
      
      // Store IS statistics
      pr.is_profit = wfa_data[INDEX_PROFIT];
      pr.is_pf = wfa_data[INDEX_PROFIT_FACTOR];
      pr.is_trades = (long)wfa_data[INDEX_TRADES];
      pr.is_drawdown = wfa_data[INDEX_REL_DD];

      int idx = ArraySize(passIS);
      ArrayResize(passIS, idx + 1);
      passIS[idx] = pr;
   }

   //======================================================
   // (B) Compute Out-of-Sample (OS) Data
   //======================================================
   FrameFirst();
   FrameFilter("WFA", 2);
   
   while (FrameNext(id, name, frame_id, value, wfa_data)) {
      PassResult pr;
      pr.pass_number = id;
      pr.os_begin = (datetime)wfa_begin_os;
      pr.os_end = pr.os_begin + (wfa_out_sample_days * 86400);

      // Retrieve parameters for this run
      string paramList = "";
      string paramArray[];
      uint paramCount;
      if (FrameInputs(id, paramArray, paramCount)) {
         for (uint k = 0; k < paramCount; k++) {
            string pieces[];
            StringSplit(paramArray[k], '=', pieces);
            if (ArraySize(pieces) < 2) continue;

            string pName = pieces[0];
            string pVal = pieces[1];

            if (IsParamSelectedForOptimization(pName)) {
               if (paramList != "")
                  paramList += " | ";
               paramList += pName + "=" + pVal;
            }
         }
      }

      pr.parameters = paramList;
      pr.window_id = GenerateWindowID(pr.os_begin, paramList);

      // Calculate OS metrics manually
      pr.os_profit = 0;
      pr.os_pf = 0;
      pr.os_trades = 0;
      pr.os_drawdown = 0;

      int tradeCount = 0;
      double totalProfit = 0;
      double grossProfit = 0;
      double grossLoss = 0;
      double maxDrawdown = 0;

      // Iterate through trades (manual OS calculation)
      HistorySelect(pr.os_begin, pr.os_end);
      int totalDeals = HistoryDealsTotal();
      
      for (int i = 0; i < totalDeals; i++) {
         ulong dealTicket = HistoryDealGetTicket(i);
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         
         if (dealTime >= pr.os_begin && dealTime <= pr.os_end) {
            tradeCount++;
            totalProfit += profit;

            if (profit > 0) {
               grossProfit += profit;
            } else {
               grossLoss += fabs(profit);
            }

            double balance = AccountInfoDouble(ACCOUNT_BALANCE);
            double equity = AccountInfoDouble(ACCOUNT_EQUITY);
            double dd = ((balance - equity) / balance) * 100;
            if (dd > maxDrawdown) maxDrawdown = dd;
         }
      }

      pr.os_profit = totalProfit;
      pr.os_trades = tradeCount;
      pr.os_drawdown = maxDrawdown;
      pr.os_pf = (grossLoss > 0) ? (grossProfit / grossLoss) : 0;

      int idx = ArraySize(passOS);
      ArrayResize(passOS, idx + 1);
      passOS[idx] = pr;
   }

   //======================================================
   // (C) Write to Summary CSV
   //======================================================
   string csvName = "WFA_Summary.csv";
   int fh = FileOpen(csvName, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if (fh == INVALID_HANDLE) {
      Print("❌ Cannot open CSV: ", GetLastError());
      return;
   }

   string hdr = "Window_ID,Pass,IS_Profit,IS_PF,IS_Trades,IS_RelDD,OS_Profit,OS_PF,OS_Trades,OS_RelDD,Parameters\n";
   FileWriteString(fh, hdr);

   for (int i = 0; i < ArraySize(passIS); i++) {
      PassResult isRec = passIS[i];

      // Find matching OS record
      int matchIndex = -1;
      for (int j = 0; j < ArraySize(passOS); j++) {
         if (passOS[j].window_id == isRec.window_id) {
            matchIndex = j;
            break;
         }
      }

      PassResult osRec = (matchIndex >= 0) ? passOS[matchIndex] : PassResult();

      string row =
         "\"" + isRec.window_id + "\"," +
         IntegerToString((int)isRec.pass_number) + "," +
         DoubleToString(isRec.is_profit, 2) + "," +
         DoubleToString(isRec.is_pf, 2) + "," +
         IntegerToString(isRec.is_trades) + "," +
         DoubleToString(isRec.is_drawdown, 2) + "," +
         DoubleToString(osRec.os_profit, 2) + "," +
         DoubleToString(osRec.os_pf, 2) + "," +
         IntegerToString(osRec.os_trades) + "," +
         DoubleToString(osRec.os_drawdown, 2) + "," +
         "\"" + isRec.parameters + "\"\n";

      FileWriteString(fh, row);
   }

   FileClose(fh);
   Print("✅ WFA_Summary.csv successfully updated.");
}
