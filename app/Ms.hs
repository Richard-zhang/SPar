module Ms where
import Spar

main :: IO ()    
-- main = benchmarking "benchmark/mergesort" [100, 99, 101, 98, 103] [0..4] [4..5] mergeSort
main = benchmarking "benchmark/intcount" [100, 99, 101, 98, 103] [0..6] [0..20] wordCount