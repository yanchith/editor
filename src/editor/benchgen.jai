load_large_text :: (view: *Document_View, approx_size_in_bytes: s64) {
    text_buffer_insert(*view.document.buffer, *view.cursors, INFINITE_JEST_CHAPTER1);

    while view.document.buffer.gb.count < approx_size_in_bytes {
        SEPARATOR :: "\n========================================================\n\n";

        text_buffer_insert(*view.document.buffer, *view.cursors, SEPARATOR);
        text_buffer_insert(*view.document.buffer, *view.cursors, INFINITE_JEST_CHAPTER1);
    }

    view.cursors.c0 = { 0, 0 };
    view.cursors.c1 = { 0, 0 };
}

#scope_file

INFINITE_JEST_CHAPTER1 :: #string DONE

YEAR OF GLAD

I am seated in an office, surrounded by heads and bodies. My posture is consciously congruent to the shape of my hard chair.
This is a cold room in University Administration, wood-walled, Remington-hung, double-windowed against the November heat,
insulated from Administrative sounds by the reception area outside, at which Uncle Charles, Mr. deLint and I were lately received.
I am in here.
Three faces have resolved into place above summer-weight sportcoats and half-Windsors across a polished pine conference
table shiny with the spidered light of an Arizona noon. These are three Deans — of Admissions, Academic Affairs, Athletic
Affairs. I do not know which face belongs to whom.
I believe I appear neutral, maybe even pleasant, though I've been coached to err on the side of neutrality and not attempt what
would feel to me like a pleasant expression or smile.
I have committed to crossing my legs I hope carefully, ankle on knee, hands together in the lap of my slacks. My fingers are
mated into a mirrored series of what manifests, to me, as the letter X. The interview room's other personnel include: the
University's Director of Composition, its varsity tennis coach, and Academy prorector Mr. A. deLint. C.T. is beside me; the others
sit, stand and stand, respectively, at the periphery of my focus. The tennis coach jingles pocket-change. There is something
vaguely digestive about the room's odor. The high-traction sole of my complimentary Nike sneaker runs parallel to the wobbling
loafer of my mother's half-brother, here in his capacity as Headmaster, sitting in the chair to what I hope is my immediate right,
also facing Deans.
The Dean at left, a lean yellowish man whose fixed smile nevertheless has the impermanent quality of something stamped
into uncooperative material, is a personality-type I've come lately to appreciate, the type who delays need of any response from
me by relating my side of the story for me, to me. Passed a packet of computer-sheets by the shaggy lion of a Dean at center, he is
speaking more or less to these pages, smiling down.
'You are Harold Incandenza, eighteen, date of secondary-school graduation approximately one month from now, attending the
Enfield Tennis Academy, Enfield, Massachusetts, a boarding school, where you reside.' His reading glasses are rectangular, court-
shaped, the sidelines at top and bottom. 'You are, according to Coach White and Dean [unintelligible], a regionally, nationally,
and continentally ranked junior tennis player, a potential O.N.A.N.C.A.A. athlete of substantial promise, recruited by Coach
White via correspondence with Dr. Tavis here commencing .. . February of this year.' The top page is removed and brought
around neatly to the bottom of the sheaf, at intervals. 'You have been in residence at the Enfield Tennis Academy since age
seven.’

I am debating whether to risk scratching the right side of my jaw, where there is a wen.
'Coach White informs our offices that he holds the Enfield Tennis Academy's program and achievements in high regard, that
the University of Arizona tennis squad has profited from the prior matriculation of several former E.T.A. alumni, one of whom
was one Mr. Aubrey F. deLint, who appears also to be with you here today. Coach White and his staff have given us —’
The yellow administrator's usage is on the whole undistinguished, though I have to admit he's made himself understood. The
Director of Composition seems to have more than the normal number of eyebrows. The Dean at right is looking at my face a bit
strangely.
Uncle Charles is saying that though he can anticipate that the Deans might be predisposed to weigh what he avers as coming
from his possible appearance as a kind of cheerleader for E.T.A., he can assure the assembled Deans that all this is true, and that
the Academy has presently in residence no fewer than a third of the continent's top thirty juniors, in age brackets all across the
board, and that I here, who go by 'Hal,' usually, am 'right up there among the very cream.' Right and center Deans smile
professionally; the heads of deLint and the coach incline as the Dean at left clears his throat:
'— belief that you could well make, even as a freshman, a real contribution to this University's varsity tennis program. We are
pleased,' he either says or reads, removing a page, 'that a competition of some major sort here has brought you down and given us
the chance to sit down and chat together about your application and potential recruitment and matriculation and scholarship.’
'I've been asked to add that Hal here is seeded third, Boys' 18-and-Under Singles, in the prestigious WhataBurger Southwest
Junior Invitational out at the Randolph Tennis Center —' says what I infer is Athletic Affairs, his cocked head showing a freckled
scalp.

'Out at Randolph Park, near the outstanding El Con Marriott,' C.T. inserts, 'a venue the whole contingent's been vocal about
finding absolutely top-hole thus far, which —’
'Just so, Chuck, and that according to Chuck here Hal has already justified his seed, he's reached the semifinals as of this
morning's apparently impressive win, and that he'll be playing out at the Center again tomorrow, against the winner of a
quarterfinal game tonight, and so will be playing tomorrow at I believe scheduled for 0830 —’
'Try to get under way before the godawful heat out there. Though of course a dry heat.’
'— and has apparently already qualified for this winter's Continental Indoors, up in Edmonton, Kirk tells me —' cocking
further to look up and left at the varsity coach, whose smile's teeth are radiant against a violent sunburn — 'Which is something
indeed.' He smiles, looking at me. 'Did we get all that right Hal.’
C.T. has crossed his arms casually; their triceps' flesh is webbed with mottle in the air-conditioned sunlight. 'You sure did.
Bill.' He smiles. The two halves of his mustache never quite match. 'And let me say if I may that Hal's excited, excited to be
invited for the third year running to the Invitational again, to be back here in a community he has real affection for, to visit with
your alumni and coaching staff, to have already justified his high seed in this week's not unstiff competition, to as they say still be
in it without the fat woman in the Viking hat having sung, so to speak, but of course most of all to have a chance to meet you
gentlemen and have a look at the facilities here. Everything here is absolutely top-slot, from what he's seen.’
There is a silence. DeLint shifts his back against the room's panelling and recenters his weight. My uncle beams and
straightens a straight watchband. 62.5 percent of the room's faces are directed my way, pleasantly expectant. My chest bumps like a
dryer with shoes in it. I compose what I project will be seen as a smile. I turn this way and that, slightly, sort of directing the
expression to everyone in the room.
There is a new silence. The yellow Dean's eyebrows go circumflex. The two other Deans look to the Director of Composition.
The tennis coach has moved to stand at the broad window, feeling at the back of his crewcut. Uncle Charles strokes the forearm
above his watch. Sharp curved palm-shadows move slightly over the pine table's shine, the one head's shadow a black moon.
'Is Hal all right, Chuck?' Athletic Affairs asks. 'Hal just seemed to ... well, grimace. Is he in pain? Are you in pain, son?’
'Hal's right as rain,' smiles my uncle, soothing the air with a casual hand. 'Just a bit of a let's call it maybe a facial tic, slightly,
at all the adrenaline of being here on your impressive campus, justifying his seed so far without dropping a set, receiving that
official written offer of not only waivers but a living allowance from Coach White here, on Pac 10 letterhead, being ready in all
probability to sign a National Letter of Intent right here and now this very day, he's indicated to me.' C.T. looks to me, his look
horribly mild. I do the safe thing, relaxing every muscle in my face, emptying out all expression. I stare carefully into the
Kekuléan knot of the middle Dean's necktie.
My silent response to the expectant silence begins to affect the air of the room, the bits of dust and sportcoat-lint stirred
around by the AC's vents dancing jaggedly in the slanted plane of windowlight, the air over the table like the sparkling space just
above a fresh-poured seltzer. The coach, in a slight accent neither British nor Australian, is telling C.T. that the whole application-
interface process, while usually just a pleasant formality, is probably best accentuated by letting the applicant speak up for
himself. Right and center Deans have inclined together in soft conference, forming a kind of tepee of skin and hair. I presume it's
probably facilitate that the tennis coach mistook for accentuate, though accelerate, while clunkier than facilitate, is from a phonetic
perspective more sensible, as a mistake. The Dean with the flat yellow face has leaned forward, his lips drawn back from his teeth
in what I see as concern. His hands come together on the conference table's surface. His own fingers look like they mate as my
own four-X series dissolves and I hold tight to the sides of my chair.
We need candidly to chat re potential problems with my application, they and I, he is beginning to say. He makes a reference
to candor and its value.

'The issues my office faces with the application materials on file from you, Hal, involve some test scores.' He glances down at
a colorful sheet of standardized scores in the trench his arms have made. 'The Admissions staff is looking at standardized test
scores from you that are, as I'm sure you know and can explain, are, shall we say ... subnormal.' I'm to explain.
It's clear that this really pretty sincere yellow Dean at left is Admissions. And surely the little aviarian figure at right is
Athletics, then, because the facial creases of the shaggy middle Dean are now pursed in a kind of distanced affront, an I'm-eating-
something-that-makes-me-really-appreciate-the-presence-of-whatever-I'm-drinking-along-with-it look that spells professionally
Academic reservations. An uncomplicated loyalty to standards, then, at center. My uncle looks to Athletics as if puzzled. He shifts
slightly in his chair.
The incongruity between Admissions's hand- and face-color is almost wild. '—verbal scores that are just quite a bit closer to
zero than we're comfortable with, as against a secondary-school transcript from the institution where both your mother and her
brother are administrators —' reading directly out of the sheaf inside his arms' ellipse — 'that this past year, yes, has fallen off a
bit, but by the word I mean "fallen off" to outstanding from three previous years of frankly incredible.’
'Off the charts.’
'Most institutions do not even have grades of A with multiple pluses after it,' says the Director of Composition, his expression
impossible to interpret.
'This kind of ... how shall I put it... incongruity,' Admissions says, his expression frank and concerned, 'I've got to tell you
sends up a red flag of potential concern during the admissions process.’
'We thus invite you to explain the appearance of incongruity if not outright shenanigans.' Students has a tiny piping voice
that's absurd coming out of a face this big.
'Surely by incredible you meant very very very impressive, as opposed to literally quote "incredible," surely,' says C.T.,
seeming to watch the coach at the window massaging the back of his neck. The huge window gives out on nothing more than
dazzling sunlight and cracked earth with heat-shimmers over it.
'Then there is before us the matter of not the required two but nine separate application essays, some of which of nearly
monograph-length, each without exception being —' different sheet — 'the adjective various evalua-tors used was quote "stellar"
—’

Dir. of Comp.: 'I made in my assessment deliberate use of lapidary and effete.’
'— but in areas and with titles, I'm sure you recall quite well, Hal: "Neoclassical Assumptions in Contemporary Prescriptive
Grammar," "The Implications of Post-Fourier Transformations for a Holographically Mimetic Cinema," "The Emergence of
Heroic Stasis in Broadcast Entertainment" —’
' "Montague Grammar and the Semantics of Physical Modality"?’
' "A Man Who Began to Suspect He Was Made of Glass"?’
' "Tertiary Symbolism in Justinian Erotica"?’
Now showing broad expanses of recessed gum. 'Suffice to say that there's some frank and candid concern about the recipient
of these unfortunate test scores, though perhaps explainable test scores, being these essays' sole individual author.’
'I'm not sure Hal's sure just what's being implied here,' my uncle says. The Dean at center is fingering his lapels as he
interprets distasteful computed data.
'What the University is saying here is that from a strictly academic point of view there are admission problems that Hal needs
to try to help us iron out. A matriculant's first role at the University is and must be as a student. We couldn't admit a student we
have reason to suspect can't cut the mustard, no matter how much of an asset he might be on the field.’
'Dean Sawyer means the court, of course, Chuck,' Athletic Affairs says, head severely cocked so he's including the White
person behind him in the address somehow. 'Not to mention O.N.A.N.C.A.A. regulations and investigators always snuffling
around for some sort of whiff of the smell of impropriety.’
The varsity tennis coach looks at his own watch.
'Assuming these board scores are accurate reflectors of true capacity in this case,' Academic Affairs says, his high voice
serious and sotto, still looking at the file before him as if it were a plate of something bad, Til tell you right now my opinion is it
wouldn't be fair. It wouldn't be fair to the other applicants. Wouldn't be fair to the University community.' He looks at me. 'And
it'd be especially unfair to Hal himself. Admitting a boy we see as simply an athletic asset would amount to just using that boy.
We're under myriad scrutiny to make sure we're not using anybody. Your board results, son, indicate that we could be accused of
using you.’
Uncle Charles is asking Coach White to ask the Dean of Athletic Affairs whether the weather over scores would be as heavy
if I were, say, a revenue-raising football prodigy. The familiar panic at feeling misperceived is rising, and my chest bumps and
thuds. I expend energy on remaining utterly silent in my chair, empty, my eyes two great pale zeros. People have promised to get
me through this.
Uncle C.T., though, has the pinched look of the cornered. His voice takes on an odd timbre when he's cornered, as if he were
shouting as he receded. 'Hal's grades at E.T.A., which is I should stress an Academy, not simply a camp or factory, accredited by
both the Commonwealth of Massachusetts and the North American Sports Academy Association, it's focused on the total needs of
the player and student, founded by a towering intellectual figure whom I hardly need name, here, and based by him on the
rigorous Oxbridge Quadrivium-Trivium curricular model, a school fully staffed and equipped, by a fully certified staff, should
show that my nephew here can cut just about any Pac 10 mustard that needs cutting, and that —’
DeLint is moving toward the tennis coach, who is shaking his head.
'— would be able to see a distinct flavor of minor-sport prejudice about this whole thing,' C.T. says, crossing and recrossing
his legs as I listen, composed and staring.
The room's carbonated silence is now hostile. T think it's time to let the actual applicant himself speak out on his own behalf,'
Academic Affairs says very quietly. 'This seems somehow impossible with you here, sir.’
Athletics smiles tiredly under a hand that massages the bridge of his nose. 'Maybe you'd excuse us for a moment and wait
outside, Chuck.’

'Coach White could accompany Mr. Tavis and his associate out to reception,' the yellow Dean says, smiling into my
unfocused eyes.
'— led to believe this had all been ironed out in advance, from the —' C.T. is saying as he and deLint are shown to the door.
The tennis coach extends a hypertrophied arm. Athletics says 'We're all friends and colleagues here.’
This is not working out. It strikes me that exit signs would look to a native speaker of Latin like red-lit signs that say HE
leaves. I would yield to the urge to bolt for the door ahead of them if I could know that bolting for the door is what the men in this
room would see. DeLint is murmuring something to the tennis coach. Sounds of keyboards, phone consoles as the door is briefly
opened, then firmly shut. I am alone among administrative heads.
'— offense intended to anyone,' Athletic Affairs is saying, his sportcoat tan and his necktie insigniated in tiny print — 'beyond
just physical abilities out there in play, which believe me we respect, want, believe me.’
'— question about it we wouldn't be so anxious to chat with you directly, see?’
'— that we've known in processing several prior applications through Coach White's office that the Enfield School is
operated, however impressively, by close relations of first your brother, who I can still remember the way White's predecessor
Maury Klamkin wooed that kid, so that grades' objectivity can be all too easily called into question —’
'By whomsoever's calling — N.A.A.U.P., ill-willed Pac 10 programs, O.N.A.N.C.A.A. —’
The essays are old ones, yes, but they are mine; de moi. But they are, yes, old, not quite on the application's instructed subject
of Most Meaningful Educational Experience Ever. If I'd done you one from the last year, it would look to you like some sort of
infant's random stabs on a keyboard, and to you, who use whomsoever as a subject. And in this new smaller company, the
Director of Composition seems abruptly to have actuated, emerged as both the Alpha of the pack here and way more effeminate
than he'd seemed at first, standing hip-shot with a hand on his waist, walking with a roll to his shoulders, jingling change as he
pulls up his pants as he slides into the chair still warm from C.T.'s bottom, crossing his legs in a way that inclines him well into
my personal space, so that I can see multiple eyebrow-tics and capillary webs in the oysters below his eyes and smell fabric-
softener and the remains of a breath-mint turned sour.
'. . . a bright, solid, but very shy boy, we know about your being very shy, Kirk White's told us what your athletically built if
rather stand-offish younger instructor told him,' the Director says softly, cupping what I feel to be a hand over my sportcoat's
biceps (surely not), 'who simply needs to swallow hard and trust and tell his side of the story to these gentlemen who bear no
maliciousness none at all but are doing our jobs and trying to look out for everyone's interests at the same time.’
I can picture deLint and White sitting with their elbows on their knees in the defecatory posture of all athletes at rest, deLint
staring at his huge thumbs, while C.T. in the reception area paces in a tight ellipse, speaking into his portable phone. I have been
coached for this like a Don before a RICO hearing. A neutral and affectless silence. The sort of all-defensive game Schtitt used to
have me play: the best defense: let everything bounce off you; do nothing. I'd tell you all you want and more, if the sounds I made
could be what you hear.
Athletics with his head out from under his wing: '— to avoid admission procedures that could be seen as primarily athletics-
oriented. It could be a mess, son.’
'Bill means the appearance, not necessarily the real true facts of the matter, which you alone can fill in,' says the Director of
Composition.
'— the appearance of the high athletic ranking, the subnormal scores, the over-academic essays, the incredible grades
vortexing out of what could be seen as a nepotistic situation.’
The yellow Dean has leaned so far forward that his tie is going to have a horizontal dent from the table-edge, his face sallow
and kindly and no-shit-whatever:
'Look here, Mr. Incandenza, Hal, please just explain to me why we couldn't be accused of using you, son. Why nobody couldcome and say to us, why, look here, University of Arizona, here you are using a boy for just his body, a boy so shy and withdrawn
he won't speak up for himself, a jock with doctored marks and a store-bought application.’
The Brewster's-Angle light of the tabletop appears as a rose flush behind my closed lids. I cannot make myself understood. 'I
am not just a jock,' I say slowly. Distinctly. 'My transcript for the last year might have been dickied a bit, maybe, but that was to
get me over a rough spot. The grades prior to that are de moi.' My eyes are closed; the room is silent. 'I cannot make myself
understood, now.' I am speaking slowly and distinctly. 'Call it something I ate.’
It's funny what you don't recall. Our first home, in the suburb of Weston, which I barely remember — my eldest brother Orin
says he can remember being in the home's backyard with our mother in the early spring, helping the Moms till some sort of garden
out of the cold yard. March or early April. The garden's area was a rough rectangle laid out with Popsicle sticks and twine. Orin
was removing rocks and hard clods from the Moms's path as she worked the rented Rototiller, a wheelbarrow-shaped, gas-driven
thing that roared and snorted and bucked and he remembers seemed to propel the Moms rather than vice versa, the Moms very tall
and having to stoop painfully to hold on, her feet leaving drunken prints in the tilled earth. He remembers that in the middle of the
tilling I came tear-assing out the door and into the backyard wearing some sort of fuzzy red Pooh-wear, crying, holding out
something he said was really unpleasant-looking in my upturned palm. He says I was around five and crying and was vividly red
in the cold spring air. I was saying something over and over; he couldn't make it out until our mother saw me and shut down the
tiller, ears ringing, and came over to see what I was holding out. This turned out to have been a large patch of mold — Orin posits
from some dark corner of the Weston home's basement, which was warm from the furnace and flooded every spring. The patch
itself he describes as horrific: darkly green, glossy, vaguely hirsute, speckled with parasitic fungal points of yellow, orange, red.
Worse, they could see that the patch looked oddly incomplete, gnawed-on; and some of the nauseous stuff was smeared around
my open mouth. 'I ate this,' was what I was saying. I held the patch out to the Moms, who had her contacts out for the dirty work,
and at first, bending way down, saw only her crying child, hand out, proffering; and in that most maternal of reflexes she, who
feared and loathed more than anything spoilage and filth, reached to take whatever her baby held out — as in how many used
heavy Kleenex, spit-back candies, wads of chewed-out gum in how many theaters, airports, backseats, tournament lounges? O.
stood there, he says, hefting a cold clod, playing with the Velcro on his puffy coat, watching as the Moms, bent way down to me,
hand reaching, her lowering face with its presbyopic squint, suddenly stopped, froze, beginning to I.D. what it was I held out,
countenancing evidence of oral contact with same. He remembers her face as past describing. Her outstretched hand, still
Rototrembling, hung in the air before mine.

'I ate this,' I said.
'Pardon me?’
O. says he can only remember (sic) saying something caustic as he lim-boed a crick out of his back. He says he must have felt
a terrible impending anxiety. The Moms refused ever even to go into the damp basement. I had stopped crying, he remembers, and
simply stood there, the size and shape of a hydrant, in red PJ's with attached feet, holding out the mold, seriously, like the report of
some kind of audit.
O. says his memory diverges at this point, probably as a result of anxiety. In his first memory, the Moms's path around the
yard is a broad circle of hysteria:
'God!' she calls out.
'Help! My son ate this!' she yells in Orin's second and more fleshed-out recollection, yelling it over and over, holding the
speckled patch aloft in a pincer of fingers, running around and around the garden's rectangle while O. gaped at his first real sight
of adult hysteria. Suburban neighbors' heads appeared in windows and over the fences, looking. O. remembers me tripping over
the garden's laid-out twine, getting up dirty, crying, trying to follow.
'God! Help! My son ate this! Help!' she kept yelling, running a tight pattern just inside the square of string; and my brother
Orin remembers noting how even in hysterical trauma her flight-lines were plumb, her footprints Native-American-straight, her
turns, inside the ideogram of string, crisp and martial, crying 'My son ate this! Help!' and lapping me twice before the memory
recedes.
'My application's not bought,' I am telling them, calling into the darkness of the red cave that opens out before closed eyes. 'I
am not just a boy who plays tennis. I have an intricate history. Experiences and feelings. I'm complex.
'I read,' I say. 'I study and read. I bet I've read everything you've read. Don't think I haven't. I consume libraries. I wear out
spines and ROM-drives. I do things like get in a taxi and say, "The library, and step on it." My instincts concerning syntax and
mechanics are better than your own, I can tell, with due respect.
'But it transcends the mechanics. I'm not a machine. I feel and believe. I have opinions. Some of them are interesting. I could,
if you'd let me, talk and talk. Let's talk about anything. I believe the influence of Kierkegaard on Camus is underestimated. I
believe Dennis Gabor may very well have been the Antichrist. I believe Hobbes is just Rousseau in a dark mirror. I believe, with
Hegel, that transcendence is absorption. I could interface you guys right under the table,' I say. 'I'm not just a creãtus,
manufactured, conditioned, bred for a function.’
I open my eyes. 'Please don't think I don't care.’
I look out. Directed my way is horror. I rise from the chair. I see jowls sagging, eyebrows high on trembling foreheads,
cheeks bright-white. The chair recedes below me.
'Sweet mother of Christ,' the Director says.
T'm fine,' I tell them, standing. From the yellow Dean's expression, there's a brutal wind blowing from my direction.
Academics' face has gone instantly old. Eight eyes have become blank discs that stare at whatever they see.
'Good God,' whispers Athletics.
'Please don't worry,' I say. 'I can explain.' I soothe the air with a casual hand.
Both my arms are pinioned from behind by the Director of Comp., who wrestles me roughly down, on me with all his weight.
I taste floor.
'What's wrong?’
I say 'Nothing is wrong.’'It's all right! I'm here!' the Director is calling into my ear.
'Get help!' cries a Dean.
My forehead is pressed into parquet I never knew could be so cold. I am arrested. I try to be perceived as limp and pliable.
My face is mashed flat; Comp.'s weight makes it hard to breathe.
'Try to listen,' I say very slowly, muffled by the floor.
'What in God's name are those . . .,' one Dean cries shrilly, '. . . those sounds?’
There are clicks of a phone console's buttons, shoes' heels moving, pivoting, a sheaf of flimsy pages falling.
'God!’
'Help!’
The door's base opens at the left periphery: a wedge of halogen hall-light, white sneakers and a scuffed Nunn Bush. 'Let him
up!' That's deLint.
'There is nothing wrong,' I say slowly to the floor. Tm in here.’
I'm raised by the crutches of my underarms, shaken toward what he must see as calm by a purple-faced Director: 'Get a grip,
son!’
DeLint at the big man's arm: 'Stop it!’
'I am not what you see and hear.’
Distant sirens. A crude half nelson. Forms at the door. A young Hispanic woman holds her palm against her mouth, looking.
'I'm not,' I say.
You have to love old-fashioned men's rooms: the citrus scent of deodorant disks in the long porcelain trough; the stalls with
wooden doors in frames of cool marble; these thin sinks in rows, basins supported by rickety alphabets of exposed plumbing;
mirrors over metal shelves; behind all the voices the slight sound of a ceaseless trickle, inflated by echo against wet porcelain and
a cold tile floor whose mosaic pattern looks almost Islamic at this close range.
The disorder I've caused revolves all around. I've been half-dragged, still pinioned, through a loose mob of Administrative
people by the Comp. Director — who appears to have thought variously that I am having a seizure (prying open my mouth to
check for a throat clear of tongue), that I am somehow choking (a textbook Heimlich that left me whooping), that I am
psychotically out of control (various postures and grips designed to transfer that control to him) — while about us roil deLint,
trying to restrain the Director's restraint of me, the varsity tennis coach restraining deLint, my mother's half-brother speaking in
rapid combinations of polysyllables to the trio of Deans, who variously gasp, wring hands, loosen neckties, waggle digits in C.T.'s
face, and make pases with sheafs of now-pretty-clearly-superfluous application forms.
I am rolled over supine on the geometric tile. I am concentrating docilely on the question why U.S. restrooms always appear
to us as infirmaries for public distress, the place to regain control. My head is cradled in a knelt Director's lap, which is soft, my
face being swabbed with dusty-brown institutional paper towels he received from some hand out of the crowd overhead, staring
with all the blankness I can summon into his jowls' small pocks, worst at the blurred jaw-line, of scarring from long-ago acne.
Uncle Charles, a truly unparalleled slinger of shit, is laying down an enfilade of same, trying to mollify men who seem way more
in need of a good brow-mopping than I.
'He's fine,' he keeps saying. 'Look at him, calm as can be, lying there.’
'You didn't see what happened in there,' a hunched Dean responds through a face webbed with fingers.
'Excited, is all he gets, sometimes, an excitable kid, impressed with —’
'But the sounds he made.’
'Undescribable.’
'Like an animal.’
'Subanimalistic noises and sounds.’
'Nor let's not forget the gestures.’
'Have you ever gotten help for this boy Dr. Tavis?’
'Like some sort of animal with something in its mouth.’
'This boy is damaged.’
'Like a stick of butter being hit with a mallet.’
'A writhing animal with a knife in its eye.’
'What were you possibly about, trying to enroll this —’
'And his arms.’
'You didn't see it, Tavis. His arms were —’
'Flailing. This sort of awful reaching drumming wriggle. Waggling,' the group looking briefly at someone outside my sight
trying to demonstrate something.
'Like a time-lapse, a flutter of some sort of awful ... growth.’
'Sounded most of all like a drowning goat. A goat, drowning in something viscous.’
'This strangled series of bleats and —’
'Yes they waggled.’
'So suddenly a bit of excited waggling's a crime, now?’
'You, sir, are in trouble. You are in trouble.’
'His face. As if he was strangling. Burning. I believe I've seen a vision of hell.’
'He has some trouble communicating, he's communicatively challenged, no one's denying that.’
'The boy needs care.’
'Instead of caring for the boy you send him here to enroll, compete?’
'Hal?’
'You have not in your most dreadful fantasies dreamt of the amount of trouble you have bought yourself, Dr. so-called
Headmaster, educator.’'. . . were given to understand this was all just a formality. You took him aback, is all. Shy —’
'And you, White. You sought to recruit him!’
'— and terribly impressed and excited, in there, without us, his support system, whom you asked to leave, which if you'd —’
'I'd only seen him play. On court he's gorgeous. Possibly a genius. We had no idea. The brother's in the bloody NFL for God's
sake. Here's a top player, we thought, with Southwest roots. His stats were off the chart. We watched him through the whole
WhataBurger last fall. Not a waggle or a noise. We were watching ballet out there, a mate remarked, after.’
'Damn right you were watching ballet out there, White. This boy is a balletic athlete, a player.’
'Some kind of athletic savant then. Balletic compensation for deep problems which you sir choose to disguise by muzzling the
boy in there.' An expensive pair of Brazilian espadrilles goes by on the left and enters a stall, and the espadrilles come around and
face me. The urinal trickles behind the voices' small echoes.
'— haps we'll just be on our way,' C.T. is saying.
'The integrity of my sleep has been forever compromised, sir.’
'— think you could pass off a damaged applicant, fabricate credentials and shunt him through a kangaroo-interview and inject
him into all the rigors of college life?’
'Hal here functions, you ass. Given a supportive situation. He's fine when he's by himself. Yes he has some trouble with
excitability in conversation. Did you once hear him try to deny that?’
'We witnessed something only marginally mammalian in there, sir.’
'Like hell. Have a look. How's the excitable little guy doing down there, Aubrey, does it look to you?’
'You, sir, are quite possibly ill. This affair is not concluded.’
'What ambulance? Don't you guys listen? I'm telling you there's —’
'Hal? Hal?’
'Dope him up, seek to act as his mouthpiece, muzzling, and now he lies there catatonic, staring.’
The crackle of deLint's knees. 'Hal?’
'— inflate this publicly in any distorted way. The Academy has distinguished alumni, litigators at counsel. Hal here is
provably competent. Credentials out the bazoo, Bill. The boy reads like a vacuum. Digests things.’
I simply lie there, listening, smelling the paper towel, watching an es-padrille pivot.

'There's more to life than sitting there interfacing, it might be a newsflash to you.’
And who could not love that special and leonine roar of a public toilet?
Not for nothing did Orin say that people outdoors down here just scuttle in vectors from air conditioning to air conditioning.
The sun is a hammer. I can feel one side of my face start to cook. The blue sky is glossy and fat with heat, a few thin cirri sheared
to blown strands like hair at the rims. The traffic is nothing like Boston. The stretcher is the special type, with restraining straps at
the extremities. The same Aubrey deLint I'd dismissed for years as a 2-D martinet knelt gurneyside to squeeze my restrained hand
and say 'Just hang in there, Buckaroo,' before moving back into the administrative fray at the ambulance's doors. It is a special
ambulance, dispatched from I'd rather not dwell on where, with not only paramedics but some kind of psychiatric M.D. on board.
The medics lift gently and are handy with straps. The M.D., his back up against the ambulance's side, has both hands up in
dispassionate mediation between the Deans and C.T., who keeps stabbing skyward with his cellular's antenna as if it were a sabre,
outraged that I'm being needlessly ambulanced off to some Emergency Room against my will and interests. The issue whether the
damaged even have interested wills is shallowly hashed out as some sort of ultra-mach fighter too high overhead to hear slices the
sky from south to north. The M.D. has both hands up and is patting the air to signify dispassion. He has a big blue jaw. At the only
other emergency room I have ever been in, almost exactly one year back, the psychiatric stretcher was wheeled in and then parked
beside the waiting-room chairs. These chairs were molded orange plastic; three of them down the row were occupied by different
people all of whom were holding empty prescription bottles and perspiring freely. This would have been bad enough, but in the
end chair, right up next to the strap-secured head of my stretcher, was a T-shirted woman with barnwood skin and a trucker's cap
and a bad starboard list who began to tell me, lying there restrained and immobile, about how she had seemingly overnight
suffered a sudden and anomalous gigantism in her right breast, which she referred to as a titty; she had an almost parodic
Québecois accent and described the 'titty's' presenting history and possible diagnoses for almost twenty minutes before I was
rolled away. The jet's movement and trail seem incisionish, as if white meat behind the blue were exposed and widening in the
wake of the blade. I once saw the word KNIFE finger-written on the steamed mirror of a nonpublic bathroom. I have become an
infantophile. I am forced to roll my closed eyes either up or to the side to keep the red cave from bursting into flames from the
sunlight. The street's passing traffic is constant and seems to go 'Hush, hush, hush.' The sun, if your fluttering eye catches it even
slightly, gives you the blue and red floaters a flashbulb gives you. 'Why not? Why not? Why not not, then, if the best reasoning
you can contrive is why not?' C.T.'s voice, receding with outrage. Only the gallant stabs of his antenna are now visible, just inside
my sight's right frame. I will be conveyed to an Emergency Room of some kind, where I will be detained as long as I do not
respond to questions, and then, when I do respond to questions, I will be sedated; so it will be inversion of standard travel, the
ambulance and ER: I'll make the journey first, then depart. I think very briefly of the late Cosgrove Watt. I think of the
hypophalangial Grief-Therapist. I think of the Moms, alphabetizing cans of soup in the cabinet over the microwave. Of Himself's
umbrella hung by its handle from the edge of the mail table just inside the Headmaster's House's foyer. The bad ankle hasn't ached
once this whole year. I think of John N. R. Wayne, who would have won this year's WhataBurger, standing watch in a mask as
Donald Gately and I dig up my father's head. There's very little doubt that Wayne would have won. And Venus Williams owns a
ranch outside Green Valley; she may well attend the 18's Boys' and Girls' finals. I will be out in plenty of time for tomorrow's
semi; I trust Uncle Charles. Tonight's winner is almost sure to be Dymphna, sixteen but with a birthday two weeks under the 15
April deadline; and Dymphna will still be tired tomorrow at 0830, while I, sedated, will have slept like a graven image. I have
never before faced Dymphna in tournament play, nor played with the sonic balls the blind require, but I watched him barely
dispatch Petropolis Kahn in the Round of 16, and I know he is mine. It will start in the E.R., at the intake desk if C.T.'s late in
following the ambulance, or in the green-tiled room after the room with the invasive-digital machines; or, given this special M.D.-
supplied ambulance, maybe on the ride itself: some blue-jawed M.D. scrubbed to an antiseptic glow with his name sewn incursive on his white coat's breast pocket and a quality desk-set pen, wanting gurneyside Q&A, etiology and diagnosis by Socratic
method, ordered and point-by-point. There are, by the O.E.D. VI's count, nineteen nonarchaic synonyms for unresponsive, of
which nine are Latinate and four Saxonic. I will play either Stice or Polep in Sunday's final. Maybe in front of Venus Williams. It
will be someone blue-collar and unlicensed, though, inevitably — a nurse's aide with quick-bit nails, a hospital security guy, a
tired Cuban orderly who addresses me as jou — who will, looking down in the middle of some kind of bustled task, catch what he
sees as my eye and ask So yo then man what's your story?

DONE;
