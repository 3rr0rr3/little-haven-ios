# Living Haven — 59.0 (64)

Seven presentation groups extend the approved small cut-paper art:

1. Guests: idle phones, existing carried luggage, door knocks on arrival, seated beach rests, night dozing, reception departure waves.
2. Conversations: contextual nods, shrugs, laughs, crossed arms and dirty-player nose-cover reactions in human dialogue portraits. Other roster/title portraits remain still.
3. Work: shoulder-attached sleeves and arms for held tools, sheet changes, mopping dust, wrench turns, counter wipes and successful supply-purchase restocking. Cleaning results still commit through the existing task completion rules.
4. Family: Hildarelys alternates watching the TV with waving; seated Samhil swings her legs. Existing TV, family choices and roaming pets remain.
5. Creatures: home cats groom, stretch, pounce in place and curl; Tuki bobs; each of twelve sanctuary residents has a themed idle detail using the original creature art.
6. Environment: cached moving palm sprites replace their static scene copies, grass sways, leaves drift, warm lantern/counter glows flicker. Existing pool ripples, beach foam and rolling waves remain. Creative-mode palm offsets are shared by rendering and collision.
7. Restaurant/bar: patrons eat and sip with attached arms, bartenders pour, counter staff wipe, distinct tray-carrying servers follow central aisles, used cups clear and return between services. Servers are decorative, never collision obstacles.

No save fields, progression, guest schedules, navigation rules or collision boundaries are added. Movement, emergency poses and real tasks override ambient poses. Standing portraits/actors use the same proportions and directional artwork.

SpriteKit renders sixteen small cached frames per active appearance, limits the cache to 48 sets, clears it on map changes, builds at most two new sets per scene update and animates only actors near the camera. Palms share eight small cached frames. No animation frame rerasterizes the map or updates business state. Compatible iOS 27 home/reception draws only independent actor views at bounded cadence. New motion respects Reduce Motion. Existing bounded AnyView startup structure remains intact; the review gallery route is DEBUG-only.

Native verification covers fifteen focused UI methods, four actual optimized office/home startup executions in both controls, game-state rules, art resources and an arm64 device build. A DEBUG gallery renders every new human/creature pose and work tool for native visual review; gameplay captures include home, conversation, restaurant, bar, beach and sanctuary.
