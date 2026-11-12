        {
          kbts__class_sequence_rule *Rule = kbts__GetClassSequenceRule(Set, RuleIndex);
          kbts_u16 *InputSequence = KBTS__POINTER_AFTER(kbts_u16, Rule);
          kbts__sequence_lookup_record *Records = (kbts__sequence_lookup_record *)(InputSequence + Rule->GlyphCount - 1);
          KBTS_DUMPF("Input: [");
          KBTS__FOR(GlyphIndex, 1, Rule->GlyphCount)
          {
            KBTS_DUMPF(", %x", InputSequence[GlyphIndex - 1]);
          }
          KBTS_DUMPF("]\nRecords: [");
          KBTS__FOR(RecordIndex, 0, Rule->SequenceLookupCount)
          {
            kbts__sequence_lookup_record *Record = &Records[RecordIndex];
            if(RecordIndex) KBTS_DUMPF(", ");
            KBTS_DUMPF("%u@%u", Record->LookupListIndex, Record->SequenceIndex);
          }
          KBTS_DUMPF("]\n");
        }

/*

static void kbts__ByteSwapSequenceContextSubtable(kbts__byteswap_context *Context, kbts_u16 *Base)
{
  if(Base[0] == 1)
  {
    kbts__sequence_context_1 *Subst = (kbts__sequence_context_1 *)Base;
    Subst->SeqRuleSetCount = kbts__ByteSwap16(Subst->SeqRuleSetCount);
    kbts__ByteSwapArray16Context(KBTS__POINTER_AFTER(kbts_u16, Subst), Subst->SeqRuleSetCount, Context);

    KBTS__FOR(SetIndex, 0, Subst->SeqRuleSetCount)
    {
      kbts__sequence_rule_set *Set = kbts__GetSequenceRuleSet(Subst, SetIndex);

      if(Set && !kbts__AlreadyVisited(Context, Set))
      {
        Set->Count = kbts__ByteSwap16(Set->Count);
        kbts__ByteSwapArray16Context(KBTS__POINTER_AFTER(kbts_u16, Set), Set->Count, Context);

        KBTS__FOR(RuleIndex, 0, Set->Count)
        {
          kbts__sequence_rule *Rule = kbts__GetSequenceRule(Set, RuleIndex);

          if(!kbts__AlreadyVisited(Context, Rule))
          {
            kbts__ByteSwapArray16Context(&Rule->GlyphCount, 2, Context);
            kbts__ByteSwapArray16Context(KBTS__POINTER_AFTER(kbts_u16, Rule), (kbts_un)Rule->GlyphCount - 1 + (kbts_un)Rule->SequenceLookupCount * 2, Context);
          }
        }
      }
    }
  }
  else if(Base[0] == 2)
  {
    kbts__sequence_context_2 *Subst = (kbts__sequence_context_2 *)Base;
    kbts__ByteSwapArray16Context(&Subst->ClassDefOffset, 2, Context);
    kbts__ByteSwapArray16Context(KBTS__POINTER_AFTER(kbts_u16, Subst), Subst->ClassSequenceRuleSetCount, Context);

    kbts_u16 *ClassDefBase = KBTS__POINTER_OFFSET(kbts_u16, Subst, Subst->ClassDefOffset);
    kbts__ByteSwapClassDefinition(Context, ClassDefBase);

    KBTS__FOR(SetIndex, 0, Subst->ClassSequenceRuleSetCount)
    {
      kbts__class_sequence_rule_set *Set = kbts__GetClassSequenceRuleSet(Subst, SetIndex);

      if(Set && !kbts__AlreadyVisited(Context, Set))
      {
        Set->Count = kbts__ByteSwap16(Set->Count);
        kbts__ByteSwapArray16Context(KBTS__POINTER_AFTER(kbts_u16, Set), Set->Count, Context);

        KBTS__FOR(RuleIndex, 0, Set->Count)
        {
          kbts__class_sequence_rule *Rule = kbts__GetClassSequenceRule(Set, RuleIndex);

          if(!kbts__AlreadyVisited(Context, Rule))
          {
            kbts__ByteSwapArray16Context(&Rule->GlyphCount, 2, Context);
            kbts__ByteSwapArray16Context(KBTS__POINTER_AFTER(kbts_u16, Rule), Rule->GlyphCount - 1 + 2 * Rule->SequenceLookupCount, Context);
          }
        }
      }
    }

    #ifdef KBTS_DUMP
    kbts__DumpClassDefinition(ClassDefBase);
    KBTS__FOR(SetIndex, 0, Subst->ClassSequenceRuleSetCount)
    {
      kbts__class_sequence_rule_set *Set = kbts__GetClassSequenceRuleSet(Subst, SetIndex);

      if(Set)
      {
        KBTS__FOR(RuleIndex, 0, Set->Count)
        {
          kbts__class_sequence_rule *Rule = kbts__GetClassSequenceRule(Set, RuleIndex);
          kbts_u16 *InputSequence = KBTS__POINTER_AFTER(kbts_u16, Rule);
          kbts__sequence_lookup_record *Records = (kbts__sequence_lookup_record *)(InputSequence + Rule->GlyphCount - 1);
          KBTS_DUMPF("Input: [");
          KBTS__FOR(GlyphIndex, 1, Rule->GlyphCount)
          {
            KBTS_DUMPF(", %x", InputSequence[GlyphIndex - 1]);
          }
          KBTS_DUMPF("]\nRecords: [");
          KBTS__FOR(RecordIndex, 0, Rule->SequenceLookupCount)
          {
            kbts__sequence_lookup_record *Record = &Records[RecordIndex];
            if(RecordIndex) KBTS_DUMPF(", ");
            KBTS_DUMPF("%u@%u", Record->LookupListIndex, Record->SequenceIndex);
          }
          KBTS_DUMPF("]\n");
        }
      }
    }
    #endif
  }
  else if(Base[0] == 3)
  {
    kbts__sequence_context_3 *Subst = (kbts__sequence_context_3 *)Base;
    kbts__ByteSwapArray16Context(&Subst->GlyphCount, 2, Context);
    kbts__ByteSwapArray16Context(KBTS__POINTER_AFTER(kbts_u16, Subst), Subst->GlyphCount + 2 * Subst->SequenceLookupCount, Context);

    kbts_u16 *CoverageOffsets = KBTS__POINTER_AFTER(kbts_u16, Subst);
    KBTS__FOR(CoverageIndex, 0, Subst->GlyphCount)
    {
      kbts__coverage *Coverage = KBTS__POINTER_OFFSET(kbts__coverage, Subst, CoverageOffsets[CoverageIndex]);

      kbts__ByteSwapCoverage(Context, Coverage);
    }
  }
}
*/

