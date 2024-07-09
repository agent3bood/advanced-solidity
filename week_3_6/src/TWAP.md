- Why does the `price0CumulativeLast` and `price1CumulativeLast` never decrement?
    - `price0CumulativeLast` and `price1CumulativeLast` are used to calculate TWAP using this
      formula `TWAP = (priceCumulativeEnd - priceComulativeStart) / (t2 - t1)`
  - It has the whole price history, so it can calculate the TWAP for any time period. 
- How do you write a contract that uses the oracle?
  - Get the price at t1 and t2, then calculate the TWAP using the formula above.
- Why are `price0CumulativeLast` and `price1CumulativeLast` stored separately? Why not just
  calculate `price1CumulativeLast = 1/price0CumulativeLast`?
  - It is more gas efficient to store them separately.
- Why overflow is desired in the `price0CumulativeLast` and `price1CumulativeLast`?
  - It is not desired, but it is not a problem because the TWAP is calculated using the difference
    between the two values.
