# Curated content review

Version 2 contains 156 original items, replacing the previous mixed-quality pool. No release or deployment has been performed.

| Kind | EN | VI | Per theme / language |
|---|---:|---:|---:|
| Read & Choose | 24 | 24 | 4 |
| Logic riddles | 18 | 18 | 3 |
| Read-aloud scenes | 36 | 36 | 6 |

Themes: `workAndStudy`, `everydayLife`, `peopleAndPlans`, `creativeBreaks`, `cityAndTravel`, `curiosity`.

## Editorial rubric

- All answer clues are supplied; exactly one answer follows. Distractors are distinct and plausible mistakes, not jokes that give the answer away.
- Explanations name the clue and answer, never choice letters or display positions: choices are shuffled.
- Explicit rules constrain number patterns, timing, quantities, and assumptions. Questions do not ask for subjective life advice.
- Vary reasoning structures, not just names. Read & Choose includes changed documents, conditional invitations, evidence limits, multi-condition choices, instructions and timing. Logic includes parallel work, a converse fallacy, cuts versus segments, mislabeled containers, capacity, intersection, exactly-one truth, directed pairs, ordering, cycles, cropping, routes, elapsed time, stop counts, explicit rules, pigeonhole reasoning and contrapositive reasoning.
- Scenes are small coherent observations with warm humor. Avoid generic affirmations, productivity guilt, health promises, inaccessible instructions and copied quotations.
- Adapt VI naturally; paired languages preserve the puzzle, not necessarily personal names or literal phrasing. Read-aloud preserves the 18–30-token recognition contract.

On 2026-10-23 the lead reviewed semantics and the parent agent independently read all 78 Vietnamese items and their 78 English pairs. They rejected repetitive drafts, reduced the planned count, and corrected ambiguous wording, semantically duplicate distractors and several translated phrases. This is an agent editorial review, not a substitute for the project owner's native-speaker release review or a user retention study.

Vietnamese items need a native-speaker review by the project owner before release.

- [ ] `read-aloud.vi.json`
- [ ] `read-and-choose.vi.json`
- [ ] `riddles.vi.json`

See [the implementation plan](../../../docs/CHALLENGE-CONTENT-PLAN.md) for behavior, checks and limits.

## Revision 3

The v3 pack adds 24 paired questions in English and Vietnamese. Twelve are
original puzzles or reading scenarios. Twelve use factual references from
NASA Science or NOAA, with original prompting, choices, explanations and
Vietnamese wording. Each fact-based item identifies its reference URL in
`attribution`. The pack keeps the same data contract and can run offline.

## Revision 4

Read Aloud selects English passages in both app languages. The 36 new passages
each have two connected sentences and 28–33 words, with familiar vocabulary
that exercises clusters, final consonants and sounds such as /θ/, /ð/ and /ʃ/.
Decoders accept 18–36 tokens. The pack retains Vietnamese voice items for
earlier clients. Other challenges still use the app language.
