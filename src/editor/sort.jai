// Slow & terrible, but with stable sorting order. Don't use for big arrays.
// Jon must never learn we use this.
bubble_sort :: (array: [] $T, f: (T) -> $R) {
    swapped := true;
    while swapped {
        swapped = false;

        for i: 1..array.count - 1 {
            i0 := i - 1;
            i1 := i;

            e0 := f(array[i0]);
            e1 := f(array[i1]);

            if e0 > e1 {
                swap(*array[i0], *array[i1]);
                swapped = true;
            }
        }
    }
}