module Main where
import Spar

instance GenRange Int where
    lBound = -10
    rBound = 10

main :: IO ()
-- main = benchmarking "benchmark/intcount" [100, 99, 101, 98, 103] [0..2] [15..20] wordCount
main = benchmarking "benchmark/intcount" [1] [0..3] [15..20] wordCount