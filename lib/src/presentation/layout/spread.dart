/// Two-page spreads: shown when the book area is at least this wide.
const double spreadMinWidth = 900;

bool useSpread(double bookPaneWidth) => bookPaneWidth >= spreadMinWidth;
