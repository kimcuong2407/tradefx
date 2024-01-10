
// Order Block Indicator MT4

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Lime
#property indicator_color2 Red

// Define input parameters
input int timeframe1 = PERIOD_H1;
input int timeframe2 = PERIOD_H4;
input int timeframe3 = PERIOD_D1;
input int timeframe4 = PERIOD_W1;

// Define indicator buffers
double bullishBlocksBuffer[];
double bearishBlocksBuffer[];

// Initialize indicator
void OnInit()
{
    // Set indicator buffers
    SetIndexBuffer(0, bullishBlocksBuffer);
    SetIndexBuffer(1, bearishBlocksBuffer);
    
    // Set indicator labels
    //SetIndexLabel(0, 'Bullish Blocks');
    //SetIndexLabel(1, 'Bearish Blocks');
    
    // Set indicator styles
    SetIndexStyle(0, DRAW_LINE);
    SetIndexStyle(1, DRAW_LINE);
    
    // Set indicator colors
    SetIndexDrawBegin(0, Bars - 1);
    SetIndexDrawBegin(1, Bars - 1);
    
    // Set indicator levels
    SetLevelStyle(0, DASHED);
    SetLevelStyle(1, DASHED);
    SetLevelValue(0, 0);
    SetLevelValue(1, 0);
    
    // Set indicator labels
    Comment('Order Block Indicator MT4');
}

// Calculate indicator values
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Perform analysis for each timeframe
    for (int i = 0; i < rates_total; i++)
    {
        // Check if price is within a bullish block
        if (close[i] > high[i + 1] && close[i] < low[i + 1])
        {
            bullishBlocksBuffer[i] = close[i];
            bearishBlocksBuffer[i] = EMPTY_VALUE;
        }
        
        // Check if price is within a bearish block
        else if (close[i] < low[i + 1] && close[i] > high[i + 1])
        {
            bearishBlocksBuffer[i] = close[i];
            bullishBlocksBuffer[i] = EMPTY_VALUE;
        }
        
        // No block detected
        else
        {
            bullishBlocksBuffer[i] = EMPTY_VALUE;
            bearishBlocksBuffer[i] = EMPTY_VALUE;
        }
    }
    
    return(rates_total);
}