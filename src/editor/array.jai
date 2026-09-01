array_copy :: (dest: [] $T, source: [] T) {
    assert(dest.count == source.count, "% == %", dest.count, source.count); // Consider relaxing to <=, if needed

    // TODO(jt): @Cleanup Not sure how memcpy deals with zero size,
    // is this if being too paranoid?
    if dest.count {
        memcpy(dest.data, source.data, source.count * size_of(T));
    }
}
