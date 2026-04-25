extends Node

@rpc("authority")
func receive_zone_category(category: String) -> void:
	MusicManager.set_ambiance_category(category)


var zones := {
	"OOC": {
		"zone_name": "OOC",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "This is the Out-of-Character zone. Here, players can gather before entering the game world.",
				"sound_path": ""

			},
			"table": {
				"image_path": "",

				"description": "You sit at the large wooden table. Notes, dice, and scribbles are everywhere.",
				"sound_path": ""

			}
		},
		"connected_zones": [""],
		"characters": []
	},

	"Test1": {
		"zone_name": "Test1",
		"default_viewpoint": "Main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This forgotten room smells like chalk and static. It waits for someone to remember why it exists.",
				"sound_path": ""

			}
		},
		"connected_zones": [],  # Hidden from normal move list
		"characters": [],
		"secret_entry_passwords": ["letmein", "testzone", "oocsecret"],
		"accessible_from_zones": ["OOC"]
	},



	"Dorchester Square": {
		"zone_name": "DorchesterSquare",
		"default_viewpoint": "Statue",
		"category":"montreal_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"Statue": {
				"image_path": "",

				"description": "The Boer War Memorial stands crooked against the drifting mist, stubborn and tired, like a name half-forgotten. Beds of red impatiens ring its base, vivid against the stone, their color too sharp, like wounds left blooming in the gloom. Dorchester Square droops around it in silence, the benches slumping like broken backs, the trees whispering to one another in brittle voices. Across the cracked pathways, you catch glimpses of tiny crosses etched into the stones, scattered as if by lost hands. Beyond the iron fences, the city heaves and flickers, broken neon bleeding into the mist. It feels like a place the world forgot.... A patch of memory struggling not to vanish.",
				"sound_path": ""

			},
			"Building": {
				"image_path": "",

				"description": "An old stone building rises alone by the edge of Dorchester Square, its walls cracked and worn by endless Montreal winters. It stands small and stubborn, a forgotten cherub surrounded by the steel giants of the city. A tired neon sign buzzes weakly against the facade, casting a sickly red glow: OUVERT. The letters flicker as if struggling to believe themselves. Its few windows, clouded and grime-streaked, offer no hint of life inside, only the heavy silence of a place long forgotten.",
				"sound_path": ""

			},
			"Sunlife": {
				"image_path": "",

				"description": "The Sun Life Building towers over Dorchester Square, its immense stonework standing as a monument to a colder age of wealth and power. It looms in stillness, vast and unmoving, while the city around it pulses with restless neon and noise. Once the tallest building in the entire British Empire, it carries that memory like a last ember of warmth, buried beneath the stone and silence.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Downtown Montreal","Dorchester Square Building","Rue de la Cathédrale"],
		"characters": []
	},



##############DORCHESTER SQUARE BUILDING#################################################################

	"Dorchester Square Building": {
		"zone_name": "DorchesterSquareBuilding",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Inside the stone building, the air feels thick, stale, almost oily against the skin. Faint neon from outside leaks through tall, grimy windows, smearing sick pinks and bruised blues across the cracked floor. The tiles underfoot are uneven, scarred by years of neglect, some darkened by stains that have long since dried into memory. A narrow, rust-bitten stairwell curls downward into a pit of shadow, the railings cold and slick to the touch. The building holds its breath in a silence so complete it feels heavy. Yet from the mouth of the stairwell rises the faintest sliver of sound, a low and uncertain hum, as if something far below was still dreaming.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Dorchester Square", "Dorchester Square Building, Stairwell 1"],
		"characters": []
	},

	"Dorchester Square Building, Stairwell 1": {
		"zone_name": "DorchesterSquareBuildingStairwell1",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The spiral staircase sinks into the earth like a wound left to fester. The walls, once carefully laid with stone, have sagged inward over time, their surfaces bruised by moisture and stained with splashes of old, faded colors that seem neither natural nor deliberate. A crude iron railing traces the curve downward, bent in places, slick with cold. The steps themselves are worn thin, their centers hollowed by decades of uncertain footsteps, the stone darkened with grime and something older. At the bottom, the stairwell disappears into a perfect black, a heavy and unnatural darkness that seems to breathe against the walls. The hum you heard above is stronger here, a deep and broken vibration, too low for comfort, as if the building itself were whispering into the hollow of the earth.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Dorchester Square Building", "Dorchester Square Building, Stairwell 2"],
		"characters": []
	},

	"Dorchester Square Building, Stairwell 2": {
		"zone_name": "DorchesterSquareBuildingStairwell2",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The stairwell coils downward, tighter and steeper with every step, until the walls seem to lean inward and the ground tilts beneath your feet. A faint dizziness clings to you, persistent and unwelcome, like the world itself is listing to one side. The silence breaks at the edges, where the low hum you first heard has thickened into a heavy purr, fast and rhythmic, alive in a way that feels almost feral. For a long while there is only darkness, pressing and absolute, but then a flickering light appears far below. It stains the stone in sickly patches of gold, wavering as if it breathes. The illusion of abandonment unravels. Beneath the grime, the chipped stone, and the years of dust, there is a trace of care, deliberate and careful. Someone still tends to this place. Not enough to comfort. Only enough to remind you that you are not alone.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Dorchester Square Building, Stairwell 1", "Dorchester Square Building, Stairwell 3"],
		"characters": []
	},

	"Dorchester Square Building, Stairwell 3": {
		"zone_name": "DorchesterSquareBuildingStairwell3",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The stairwell bends and spills you onto a narrow platform, a ledge of battered stone barely clinging to the wall. The air grows heavier with each step, carrying a slow vibration that presses against your skin. The walls bleed muted colors that shift and shimmer at the edge of sight, too deep and too worn to catch clearly. The unease is no longer something you can shake off. It gathers around you, dense and rhythmic, thrumming through the stone underfoot. Far below, a sound rises, slow at first, then faster, shaping itself into something almost familiar. The tremors climb the railings, brushing your fingertips, moving through the soles of your boots. For a moment, standing still, you can almost mistake it for the breath of the earth itself. Then, between two beats, it sharpens. This is not the whisper of forgotten stone or the groan of empty tunnels. It is music. Heavy, alive, wild, spilling upward from somewhere unseen. Something waits down there, and it is already awake.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Dorchester Square Building, Stairwell 2", "Dorchester Square Building, Stairwell 4"],
		"characters": []
	},

	"Dorchester Square Building, Stairwell 4": {
		"zone_name": "DorchesterSquareBuildingStairwell4",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The stairwell uncoils at last, spitting you onto a narrow landing carved into the rock. A door waits there, heavy and battered, leaning slightly on its hinges like it is just as tired of holding back the noise as you are of chasing it. The music is louder now, thick and pulsing through the cracks, but the door remains stubborn, unmoved, offering no grand revelation. No final warning. Just wood, stone, and the sound of something on the other side having a much better time than you are. For a moment, everything you carried with you on the way down, all the tension and expectation, hangs uselessly in the air. The only thing left to do is knock, or push, or turn back. If you still remember how.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Dorchester Square Building, Stairwell 3", "Crypt Club"],
		"characters": []
	},

	"Crypt Club": {
		"zone_name": "Crypt Club",
		"default_viewpoint": "Front",
		"category":"Club001",
		"is_neighborhood": false,
		"viewpoints": {
			"Front": {
				"image_path": "",

				"description": "The door gives way, and the world bursts open. Color spills across the stone like liquor. Red velvet couches sag under murmuring bodies, sharp laughter cuts through the thick air, and the vaulted ceilings, carved long ago for another purpose, catch every flicker of neon. The walls still remember. This was a crypt once, or something close to it, and no amount of light or music has chased away the cold in the stone. The music pounds, not just heard but felt through the bones of the floor. Smoke coils through the crowd, softening faces that seem too still, too poised, like statues warmed back to life. Conversations crash together in a tide of hunger and longing, sharp and bright against the dark. This is the pulse of the city. Not the towers, not the monuments, but here, underground, hidden among old bones, burning itself bright enough to be seen by the dead.",
				"sound_path": ""

			},
			"Back": {
				"image_path": "",

				"description": "At the far end of the club, the chaos gives way to a strange clearing. A dance floor sprawls under the old stone arches, slick with neon reflections, pounding with the heavy breath of the music. In the center, absurd and immovable, stands a throne. Blood-red velvet, cracked gold trim, the kind of thing that should belong to a fever dream or a failed revolution, not here among the sweat and bass.\
	The dancers twist and lurch around it, caught in the music, never touching, never even glancing at the thing. It does not belong, but it does not care. It watches, heavy and smug, basking in a ceremony nobody remembers starting.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Dorchester Square Building, Stairwell 4", "Temple of Eternal Whispers: The Crypts"],
		"characters": []
	},
	
	# ---------- Iron Veil: Maven's Office Zone ----------
	"Iron Veil: Maven's Office": {
		"zone_name": "Iron Veil: Maven's Office",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Maven's office lies in a stone walled chamber where the thrum of the club barely penetrates, persistent as a heartbeat. 

Neat executive bookshelves line the area with dark wood, elegant and understated. The center is a matching desk, with 3 high backed wooden chairs - one for the owner, and 2 for guests.

Every inch screams tradition and persistence; as constant as a shadow as the Sabbat moves toward its destiny.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Crypt Club"],
		"characters": [],
		"secret_entry_passwords": ["silence"],
		"accessible_from_zones": ["Crypt Club","Temple of Eternal Whispers: The Crypts"]
	},
# ---------- Iron Veil: Ritual Chamber Zone ----------
	"Iron Veil: Ritual Chamber": {
		"zone_name": "Iron Veil: Ritual Chamber",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A crypt converted into a ritual room most commonly used by the Iron Veil's pet blood mage, Anatole Vex of House Goratrix.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Crypt Club"],
		"characters": [],
		"secret_entry_passwords": ["ritual"],
		"accessible_from_zones": ["Crypt Club", "Temple of Eternal Whispers: The Crypts"]
	},

# ---------- Temple of Eternal Whispers: The Crypts Zone ----------
	"Temple of Eternal Whispers: The Crypts": {
		"zone_name": "Temple of Eternal Whispers: The Crypts",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Beyond the thrumming base of the Iron Veil's club front, are the great network of crypts that make up the Temple of Eternal Whispers - the grand Communal Haven of Montreal. 

Built in 1790s by the former Archbishop (now Regent) Kyle Strathcona, the Temple made way for more urban development in the center of Montreal by turning a former graveyard into a necropolis beneath the city streets.

Many of the temple's hallways and smaller chambers are lined with the crypts of the 1832 & 1853 cholera epidemic victims. A majority of the crypts were emptied long ago of their inhabitants and are now used only by the Sabbat as temporary bunkers or boltholes when other Havens are compromised. 

A number of tombs have been adopted and personalized by individual packs. Not every pack has a lair in the Temple of Eternal Whispers, but each has at least one crypt that it can call home should the need arise.
",
				"sound_path": ""
			},
		},
		"connected_zones": ["Crypt Club","Temple of Eternal Whispers"],
		"characters": [],
	},
	
	# ---------- The Chambre Voilée Zone ----------
	"The Chambre Voilée": {
		"zone_name": "The Chambre Voilée",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The  Chambre Voilee is carved from old colonial stone, its walls slick with condensation and streaked with iron-rich veins that resemble dried blood.

 The ceiling arches low, supported by rib-like buttresses carved to resemble vertebrae. Candles burn in sconces made from bone, their wax pooling in skull-shaped basins.

The air is heavy with incense and stillness, smelling of myrrh, grave dust, and something coppery. A faint hum pulses through the stone, like the echo of a buried heart.

An obsidian altar stands in the center of the chapel-like interior, the wall behind it full of cubbies, each bearing a name. Some hold pieces of verse or the Book of nod; some hold grave objects of the dead.

Two doors lead off of this central room, one to the immediate right, and one toward the back, to the side of the altar.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Temple of Eternal Whispers: The Crypts", "The Bleeding Annex", "The Cavern of Rejected Names"],
		"characters": [],
		"secret_entry_passwords": ["echo"],
		"accessible_from_zones": ["Temple of Eternal Whispers: The Crypts"]
	},

	
# ---------- Temple of Eternal Whispers Zone ----------
	"Temple of Eternal Whispers": {
		"zone_name": "Temple of Eternal Whispers",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The Temple is named for the soft, almost inaudible moans and bellows that echo through its halls. Many cholera victims were buried alive after being declared officially dead by frightened doctors. Those poor souls awoke to discover that their bodies have been sealed into crypts or dumped into mass graves. Their screams echoed through the night, much to the enjoyment of the Sabbat. Thanks to the design of the mausoleum, with its high, vaulted ceilings, these haunting sounds can be heard to this night. 

The central chamber boast a 30ft ceiling, and is large enough to accomodate over 500 vampires. It is usually packed during the opening of the Litany, a sacred event held in the summer months.he chamber is crowned by an intricate glass depiction of Gehenna. Under this sits the Archbishop's throne, made from human bone. The central mausoleum is lined by two levels of crypts along three of its four walls. The upper crypts are accessible by two spiraling staircases and they form a balcony that overlooks the room. 

The lower crypts lead back to further chambers, including the haven of La  Voix Saignante, the keepers of the Litany, and the Chapel of Caine.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Temple of Eternal Whispers: The Crypts","Temple of Eternal Whispers: Caine's Chapel"],
		"characters": []
	},
	
# ---------- Temple of Eternal Whispers: Caine's Chapel Zone ----------
	"Temple of Eternal Whispers: Caine's Chapel": {
		"zone_name": "Temple of Eternal Whispers: Caine's Chapel",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "One of the most beautiful chambers in the Temple, this small chapel is dedicated to Caine and has small altars where followers may pray and meditate, one for each of the Sabbat's formally recognized Paths of Enlightenment - Path of Caine, Path of Cathari, Path of Power & Inner Voice,  Path of Death & The Soul, Path of Night, Path of Feral Heart, and the Path of Nocturnal Redemption. The former Altar of Harmony was clawed apart by the followers of the Path of the Feral Heart. It has not been rebuilt.",
				"sound_path": ""
			},
			"Gates of Eternity": {
				"image_path": "",

				"description": "The bronze doors stand silent and cold, sealed against all entry as one passes through Caine's Chapel. Beyond is said to lie the great Alexandrium, a library of vampire lore maintained by the pack La Voix Saignante.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Temple of Eternal Whispers"],
		"characters": []
	},


##############################################################################################################################


	"Rue de la Cathédrale": {
		"zone_name": "RuedelaCathédrale",
		"default_viewpoint": "main",
		"category":"montreal_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The \"Rue de la Cathédrale\" curls along the edge of the \"Basilique Marie-Reine-du-Monde\", slick with rain and humming faintly under old streetlights.\n
The basilica itself rises in heavy, baroque lines, its domes and crosses clawing at a sky smeared with neon and soot. For a moment, it almost feels like the world should still be bending to it.\n
But the city has grown around it like a tide swallowing a rock.\n
On one side, the Sun Life Building, cold and massive, watches with the patience of an old king. On the other, the \"1000 de la Gauchetière\" scrapes the mist with its sterile glass bones. Together they pin the basilica in place, a monument to a grandiosity nobody has time for anymore.\n
The lights of the street stutter in the puddles. Somewhere farther off, a car coughs and dies in the distance. The old church stands silent, proud, and strangely small, like a voice trying to shout through a storm that has already moved on.",
				"sound_path": ""

			}
		},
		"connected_zones": ["1000 de la Gauchetière", "Dorchester Square", "Downtown Montreal"],
		"characters": []
	},


	"1000 de la Gauchetière": {
		"zone_name": "Gauchetiere",
		"default_viewpoint": "Outer",
		"category":"montreal_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"Outer": {
				"image_path": "",

				"description": "At \"1000 de la Gauchetière\", the building gave up a long ago.\n
	It is no longer a landmark. It is no longer a vision of the future.\n
	It is a passage, a lobby, a slightly cleaner shortcut to the Bonaventure Metro tucked inside its bones.\n
	Footsteps fill the atrium, fast and careless. The city's blood pumping through marble floors and glass walls, never stopping to look around.\n
	Above it all, the skating rink drifts in slow, ridiculous circles. A museum piece nobody asked for, spinning endlessly under lights that forget to shine.\n
	The building no longer pretends to matter.\n
	It holds the Metro in its gut, lets the city pass through its ribs, and stands there. A shell of ambition, pressed flat under all the weight it was supposed to carry.",
				"sound_path": ""

			},
			"Entrance": {
				"image_path": "",

				"description": "The entrance to \"Mille de la Gauchetière\" stands under the cold streetlights, its name stretched wide above the revolving doors in bold, aging letters.\n
	There is no sign for the Metro. No hint that Bonaventure, the real reason anyone comes here, lies buried just beyond the glass.\n
	Only the building’s own name, flaunted with the stubbornness of something too proud to admit it has been reduced to a hallway.\n
	Out of jealousy... out of spite, it offers no directions.\n
	If you do not already know, you are not invited to learn.\n
	A few homeless figures drift near the entrance, quiet and half-seen, blending into the stone and glass like old stains.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Rue de la Cathédrale", "Downtown Montreal", "Bonaventure Metro"],
		"characters": []
	},

#####################################################################
####################### Metro Zones ##############################


# ---------- North Metro Maintenance Tunnels Zone ----------
	"North Metro Maintenance Tunnels": {
		"zone_name": "North Metro Maintenance Tunnels",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The tunnels in this section are narrow, the kind of space that forces shoulders to brush against damp, sweating walls. Old maintenance signage, rusted beyond legibility, clings crookedly to the concrete. The air hangs heavy, stagnant, carrying the tang of mildew, corroded metal, and the faint rot of something not entirely organic. Faded yellow paint still marks the floor’s edge where workers once walked, though in places it’s been worn down to bare stone by something dragging itself through, back and forth, over and over.

Pipes line the ceiling, many dripping in steady, echoing droplets, and electrical conduits snake along the walls with their insulation peeling away like old skin. Fluorescent tubes remain in their cages, but none have glowed for years; the only light comes in uneven shafts through corroded grates above, casting broken patterns of shadow.

It is in those shadows that an infestation breathes; cold, grave-like chill stealing over you as you realize that you are not alone in these tunnels. Something is hunting you.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Saint-Michel Metro", "Saint-Michel Metro - Exterior", "Namur Metro"],
		"characters": []
	},


# ---------- Inbound Train Zone ----------
	"Inbound Train": {
		"zone_name": "Inbound Train",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The interior of the metro train feels a little worn, as if it's seen years of daily hustle and hurried journeys. The seats are a dull, faded blue, some with frayed edges or small stains that give away their age. The floor is a mix of scraped tiles and grimy patches where feet have dragged across, creating an uneven, rough surface underfoot. The air is thick with a blend of sweat, cologne, and the metallic scent of the train’s inner workings.

The overhead lights flicker occasionally, casting a dim glow over the passengers who are huddled in their own little worlds. Some wear headphones, eyes glazed over, while others stare out the fogged-up windows that are streaked with grime. The graffiti-tagged poles and walls are a stark contrast to the sterile cleanliness of the newer trains further up the line. Every so often, the train jerks forward with an unsettling squeal of metal, rattling those who are too tired to brace themselves.

At the back of the car, the atmosphere shifts. The clattering sound of heels and casual chatter grows louder as the train moves closer to downtown. The passengers’ attire shifts too—rough, faded jackets and scuffed shoes turn into sharp business suits and polished leather bags. There’s a subtle, almost imperceptible change in the air, as if the city’s pulse picks up with every passing station.

Through the windows, the view changes. Where graffiti once covered the walls, bright billboards and clean, glass buildings begin to rise, signaling the transition from gritty neighborhoods to gleaming downtown. The sounds, too, change—a cacophony of city noises—while the inside of the train feels the last remnants of the seedy edge slowly being swallowed by the buzz of the city’s heart.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Saint-Michel Metro", "Namur Metro", "Bonaventure Metro", "South Metro Maintenance Tunnels"],
		"characters": [],
		"secret_entry_passwords": ["Inbound"],
		"accessible_from_zones": ["Bonaventure Metro", "Saint-Michel Metro", "Namur Metro", "Place des Arts Metro"]
	},

# ---------- South Metro Maintenance Tunnels Zone ----------
	"South Metro Maintenance Tunnels": {
		"zone_name": "South Metro Maintenance Tunnels",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The tunnels run like forgotten arteries beneath the city, a world abandoned by the living but not yet emptied of presence. The walls are poured concrete, flaking in places where water seeps through hairline cracks, leaving long rust-colored streaks that look like veins. Pipes line the ceilings and walls, some groaning faintly with the weight of water, others long dead, their joints crusted with mineral blooms. Every sound—the drip of condensation, the shuffle of rats, the distant echo of machinery from far-off lines—multiplies in the narrow space until it feels like the air itself is listening.

Stray light leaks in through grated vents, thin and broken, striping the darkness with pale shafts that reveal fragments: a discarded glove stiffened with age, a broken radio half-sunk in grime, a service hatch with its lock twisted long ago. Spray-painted symbols in layers mark the walls, some crude tags, others stranger—circles, arrows, or cryptic initials—hinting at the passage of those who use the tunnels for purposes not listed in any municipal records.

The air carries the sour tang of mold and rust, undercut by something faintly chemical, as if old spills have never fully dried. Here and there, the walls open into side corridors blocked by collapsed debris, or doorways leading into pitch-black service rooms, their contents long since stripped or scattered. The silence is never absolute; there is always a suggestion of motion at the edge of hearing, as if the tunnels breathe with their own hidden rhythm.

It feels less like a place of work and more like a buried labyrinth, a place where the city hides what it cannot dispose of: histories, secrets, and perhaps things that were never meant to be found.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Place des Arts Metro", "Bonaventure Metro", "Inbound Train"],
		"characters": [],
	},

# ---------- Outbound Train Zone ----------
	"Outbound Train": {
		"zone_name": "Outbound Train",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The train hums like a tired heartbeat, carrying its cargo of lives through the city’s hidden veins. Light flickers in the windows, not steady, but fractured—brief flashes of tiled walls, black tunnels, and the blur of stations sliding past. The car itself feels like a vessel between worlds: plastic seats etched with names long forgotten, a floor scuffed into a dull map of footsteps that once pressed here and moved on.

Each stop exhales a different breath. In the low-income district, the train swells with weary shoulders, work boots streaked with dust, the faint smell of sweat and machine oil. Voices murmur low, some trailing into silence as heads rest against rattling glass. As the train pushes deeper, the cadence shifts. Bags filled with produce and spices rustle against knees. A lullaby in a language not native to the city threads through the clatter of wheels. The air changes subtly, carrying the warmth of kitchens, of markets, of home carried on the body.

The faces in the car hold fragments of stories that do not meet each other’s eyes, yet share the same dim light, the same metal floor, the same unrelenting forward motion. It is a passage not just of geography but of belonging—the line itself a bridge between margins, each stop a threshold where one life fades into another.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Bonaventure Metro", "Namur Metro", "Saint-Michel Metro", "North Metro Maintenance Tunnels"],
		"characters": [],
		"secret_entry_passwords": ["Outbound"],
		"accessible_from_zones": ["Bonaventure Metro", "Saint-Michel Metro", "Namur Metro", "Place des Arts Metro"]
	},

# ---------- Place des Arts Metro Zone ----------
	"Place des Arts Metro": {
		"zone_name": "Place des Arts Metro",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Beneath the city, Place-des-Arts station feels less like a passage for commuters and more like a cavern of forgetting. The concrete vaults arch above in heavy silence, their surfaces dulled to a shadowed grey. The lighting is uneven—fluorescent tubes flicker in pale rhythms, some humming faintly, others extinguished long ago, leaving stretches of platform in semi-darkness. Each patch of shadow seems deeper than it should be, as though the station breathes in long, heavy pauses.

The tiled walls reflect almost nothing. Their surfaces are scuffed, dulled, faintly damp, and in certain angles the patterns of stains resemble faces—blurred and mournful, never quite clear enough to focus on. Footsteps echo strangely here, not cleanly but stretched, as if someone else is walking just a fraction of a beat behind you. The sound of a train approaching grows into a howl through the tunnels, metallic and ragged, then diminishes too quickly, leaving a hollow quiet that presses on the chest.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Namur Metro", "Bonaventure Metro", "Saint-Michel Metro", "Underground City", "South Metro Maintenance Tunnels"],
		"characters": [],
	},

###############################Blue Bonnet Area#####################


	"Namur Metro": {
		"zone_name": "NamurMetro",
		"default_viewpoint": "Main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"Line": {
				"image_path": "",

				"description": "Namur s’endort dans l’écho des wagons,\n\
	Ses murs suintent l’hiver, la peur, le silence,\n\
	Chaque marche résonne un vieux nom,\n\
	Une plainte oubliée sans délivrance.\n
	Le sol est fendu comme un cœur trop battu,\n\
	L’air sent la rouille, la pluie, les adieux,\n\
	Quelque chose attend, tapi, jamais vu,\n\
	Sous les pierres noircies, sous les cieux creux.\n
	Ici le temps se courbe et se confesse,\n\
	Les pas s’égarent, avalés sans retour.\n\
	Namur conserve en elle une promesse :\n\
	Qu’un jour tout s’effondre. Même l’amour.",
				"sound_path": ""

			},
			"Main": {
				"image_path": "",

				"description": "Most people don’t really notice Namur. It’s not the kind of station that asks to be remembered.\n
	Buried under layers of concrete and old decisions, it sits quiet, a little stained, a little out of step.\n
	The ceiling’s strange geometry hangs overhead like a question no one wants answered. The floors are always damp, the walls feel older than they should, and the turnstiles creak like they’ve been spinning since the '70s.\n
	Nothing here feels urgent. It’s just another stop. Tired, but still working.\n
	Namur has the look of a place that used to matter a little more. Maybe it never did. It holds onto that uncertain feeling, like waiting for a train that’s technically on time but somehow never coming.\n
	The lighting is off, the signs a bit faded, but the rhythm continues. People come and go, lost in their own loops.\n
	And the station keeps doing what it always has: carrying the weight of a city that doesn’t look back much. Not because it’s too bold to remember, but because memory takes time, and nobody here has any to spare.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Bonaventure Metro", "Place des Arts Metro", "Saint-Michel Metro", "Décarie Sector", "North Metro Maintenance Tunnels"],
		"characters": []
	},


	"Décarie Sector": {
		"zone_name": "DecarieSector",
		"default_viewpoint": "namur_outside",
		"category":"montreal_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"Outside Namur Station": {
				"image_path": "",

				"description": "Namur doesn’t try to impress. A squat metro entrance tucked just off the Décarie, half-drowned in the noise of traffic and long-haul fatigue.\n
	The building looks like it’s been standing still while the city forgets how to. Concrete walls stained with time, glass that reflects more past than present.\n
	The glowing “MÉTRO” sign does its best to suggest function, but it’s the only thing here pretending to be awake.\n
	People don’t come to Namur for what’s on her side. They cross the street, cross the highway, toward something else entirely.\n
	In the distance, the Orange Julep hums like a roadside relic, its glow leaking into the mist like a memory that won’t settle.\n
	A little farther, the old Blue Bonnets grounds stain the sky with a cold electric haze.\n
	It’s almost funny: Namur is the stop, but everything people want is just beyond it.\n
	Still, the station stays. Not out of pride, not out of hope, just because that’s what it’s always done. Stand still, open late, and wait for someone heading somewhere else.",
				"sound_path": ""

			},
			"Above Décarie Crossing": {
				"image_path": "",

				"description": "The overpass above the Décarie looks like any other slab of city infrastructure: useful, ignored, and falling apart in just the right ways.\n
	By day, it’s a bottleneck of metal and misery, the rat race compressing itself into four narrow lanes of deadlock and frustration.\n
	Horns blare, tempers crack, and the sun bakes it all like a bad idea left out too long.\n
	But by night? It’s almost peaceful. Empty, echoing, like the city held its breath and forgot to exhale. A few “vroom-vroom” and “beep-beep” there.\n
	Nobody walks here after dark unless they have to. The lights hum. The rails are rusted. The concrete feels like it remembers things you’d rather not.\n
	In the distance, buildings flicker in and out of view, their windows glowing like half-lidded eyes.\n
	It’s not dangerous, not exactly. Just quiet in a way that makes you think too long.\n
	Most people stay inside when it gets like this. Not out of fear. Just instinct.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Namur Metro", "Orange Julep", "Blue Bonnets", "Côte-des-Neiges"],
		"characters": []
	},

	"Orange Julep": {
		"zone_name": "OrangeJulep",
		"default_viewpoint": "main",
		"category":"montreal_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The Orange Julep squats by the side of the Décarie Expressway, an enormous, fucking massive orange dropped into a city too tired to wonder why.\n
	Its surface is cracked and battered, drinking in the sour light of the streetlamps, a bloated relic that refuses to die.\n
	Strips of torn bunting twitch in the oily wind, clinging to rusted poles like old party favors from a celebration everyone forgot.\n
	The highway groans without pause. Angry honks and screeching tires rise into the mist, swallowed by the night.\n
	Farther off, the lights of the old Blue Bonnets racetrack stab at the darkness, too clean, too empty, a carnival with no music.\n
	And yet, they still come.\n
	A thin line of patrons stretches from the service windows, hands shoved deep in their pockets, shoulders hunched against the rain.\n
	They queue for the only thing the Julep still offers: the Julep Special, a frothy orange drink whose recipe is a secret so fiercely guarded it might as well be sacred.\n
	No menus, no questions. Just the ritual, played out under the cracked skin of the giant fruit.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Décarie Sector", "Blue Bonnets"],
		"characters": []
	},

	"Blue Bonnets": {
		"zone_name": "BlueBonnets",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Blue Bonnets runs most nights. Not packed, not empty. Just enough to keep the engines turning.\n
	The track lights buzz overhead, casting long shadows across worn pavement and concrete bleachers.\n
	The signage is old, the colors are faded, but everything still works. Vendors sell warm beer and paper bags of fries.\n
	The regulars line the fence, eyes locked on the dirt. You can still feel the tension before a race. Quiet. Sharp. Real.\n
	It’s not a destination, but it has gravity. People don’t come here to be impressed.\n
	They come to get out of the house, to feel something quick and alive pass in front of them.\n
	The crowd swells when a favorite pulls ahead. A few bills change hands just fast enough not to be noticed.\n
	No one talks about history. No one needs to.\n
	Blue Bonnets is doing exactly what it's supposed to do: keep the night moving, one lap at a time.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Orange Julep", "Décarie Sector", "Blue Bonnets : Entrance"],
		"characters": []
	},

	"Blue Bonnets : Entrance": {
		"zone_name": "BlueBonnetsEntrance",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The entrance hall at Blue Bonnets is fine. Nothing special, nothing broken.\n
	Fluorescent lights buzz overhead, some warmer than others.\n
	The tiles along the wall are set in colored diamond patterns, probably meant to feel lively. They don’t. But they try.\n
	There’s a hotdog stand tucked into one corner and a small ice cream spot near the far side, both half-open, half-bored.\n
	The kind of places that don’t push you to buy anything. They just exist, like the rest of the space.\n
	The air carries a mix of fried onions, sugar, and damp concrete.\n
	Most people pass through without thinking, heading straight for the track, but if you stop for a second, the quiet hum of it all settles into something almost comfortable.\n
	Not inviting. Just familiar.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Blue Bonnets", "Blue Bonnets : Hall"],
		"characters": []
	},


	"Blue Bonnets : Hall": {
		"zone_name": "BlueBonnetsHall1",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Farther in, the hall splits. One path keeps going straight, past shuttered windows and cheap tile, toward the regular stands.\n
	The other turns upward, an old escalator groaning beneath yellowed lights.\n
	A plaque on the wall reads *Le Centaure* in serif gold. It points toward the buffet upstairs. Quieter, cleaner, more expensive.\n
	People don’t always decide out loud. Some glance up, think about it, and keep walking. Others take the ride.\n
	Up there, the chairs are padded, the drinks don’t come in plastic, and the food isn’t half-bad.\n
	Down here, it’s louder, messier, more real.\n
	It’s not about class so much as mood. The building doesn’t judge. It just waits for you to make your call.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Blue Bonnets : Entrance", "Blue Bonnets : Stands", "Blue Bonnets : Hall Centaur"],
		"characters": []
	},

# ---------- The Final Curve Zone ----------
	"The Final Curve": {
		"zone_name": "The Final Curve",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The Final Curve at Blue Bonnets isn't just another stretch of racetrack, it's the private den of the Blue Blood and Soil pack, hidden behind locked service doors beneath the grandstand. From the outside it looks like a maintenance wing, but inside it opens into a velvet-lit lounge with tinted windows overlooking the last turn where horses thunder by in a frenzy of speed. Plush leather booths line the walls, stained with wine and vitae, while tables are littered with betting slips, half-finished glasses, and the remnants of indulgences. The air hums with muffled jazz and the scent of blood, the roar of the mortal crowd outside reduced to a distant thrum as if the room exists apart from reality. Security is tight, ghouls watch the entrance, checking passes and eyes alike, while the locks are reinforced with steel and silver. For mortals, the space is a gilded VIP gallery; for Cainites, it's a playground dressed as civility, where predators drink, gamble, and scheme under the steady rhythm of hooves pounding the dirt just beyond the glass.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Blue Bonnets : Hall"],
		"characters": [],
		"secret_entry_passwords": ["Break the Quiet"],
		"accessible_from_zones": ["Blue Bonnets : Hall"]
	},


	"Blue Bonnets : Stands": {
		"zone_name": "BlueBonnetsStands",
		"default_viewpoint": "Stand 1",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"Stand 1": {
				"image_path": "",

				"description": "The first set of stands is nothing fancy. Plastic seats, most of them scratched or cracked at the edges, some still warm from the last person who sat there.\n
	The floor sticks a little. Someone always spills something. But the view is good! A full sweep of the track behind tall glass panels, streaked with fingerprints and the occasional lost flyer taped from the inside.\n
	The lighting overhead hums with that soft, uneven flicker that settles into the back of your eyes if you sit too long.\n
	You hear the muffled buzz of the announcer somewhere, mixed with the rustle of betting slips and casual arguments.\n
	Nobody dresses up down here. They come for the race, the rhythm, the motion. No distractions. Just seats, a view, and the next heat lining up.",
				"sound_path": ""

			},
			"Stand 2": {
				"image_path": "",

				"description": "Farther in, the crowd thins out. The seats stretch on in long, quiet rows, and most of them are empty.\n
	The lights overhead flicker less out of neglect and more from habit. Paint chips from the ceiling. Dust gathers near the far edges where nobody really sits anymore.\n
	The smell here is older — part dry concrete, part paper, part stale snack grease that never fully leaves.\n
	Out the window, the track keeps moving. The glass is streaked, but the view holds.\n
	Sunset bleeds across the sky and reflects in a dozen uneven panels, cutting the dirt track in amber and violet.\n
	There's a monitor hanging from the ceiling, too far back to see clearly. No one seems to mind.\n
	The regulars who end up in this part don’t need the screen. They’ve been coming long enough to know how to watch.",
				"sound_path": ""

			},
			"Stand 3": {
				"image_path": "",

				"description": "The farther you go, the more it all starts to blur together. Row after row, seat after seat, same angle, same dust, same fluorescent hum from above.\n
	The backs of the chairs are scuffed in the same places. The gum underneath is the same pale gray.\n
	Time doesn’t feel like it passes here so much as it loops. One lap, then another.\n
	This part of the stands isn't empty out of neglect. It’s just quiet. Some people like it that way.\n
	You can sit without talking. You can watch without being watched.\n
	You hear the same horse names get called. The same bets placed. The same small reactions: cheers, groans, silence.\n
	Monotony isn’t failure here. It’s rhythm. It's what the building was made for.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Blue Bonnets : Hall"],
		"characters": []
	},


	"Blue Bonnets : Hall Centaur": {
		"zone_name": "BlueBonnetsHallCentaur",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The stairs up to Le Centaure aren’t elegant. Just concrete and tile, lit by flickering strips of neon that shift between a tired red and a cold, humming blue.\n
	The walls are close here, lined with stains that no one’s bothered to clean in a long time.\n
	The air grows heavier with each step, like the oxygen’s been filtered through too many stories, none of them pleasant.\n
	You start to hear less from the track below. The crowd noise fades. The footsteps echo longer.\n
	No one says anything, but something about this stretch makes people straighten up a little. Like they’re being watched, or expected.\n
	There’s no sign of luxury yet, just a narrow turn and another flight of stairs.\n
	Still, the name hangs in your mind: Le Centaure. Sounds classy. Feels distant.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Blue Bonnets : Hall", "Le Centaure"],
		"characters": []
	},

	"Le Centaure": {
		"zone_name": "LeCentaure",
		"default_viewpoint": "Entrance",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"Entrance": {
				"image_path": "",

				"description": "This isn’t what you pictured. Le Centaure was supposed to be the nice part, the break from the grime.\n
	But the first thing that greets you is silence. Not calm, but muffled, like the sound’s been drained out of the room on purpose.\n
	The escalator behind you hums softly, empty. Ahead, the carpet is patterned and clean, but it feels damp underfoot. The kind of damp that doesn’t come from water.\n
	There’s a wide glass wall, floor to ceiling, showing the track below. But the view doesn’t reassure. The lights outside flicker orange through the mist, each one oddly distant, like you're watching someone else's memory.\n
	The air smells faintly of old plastic and something sweet gone wrong.\n
	No one’s here to welcome you. No music plays. Just that strange hush, like the building is waiting to see who turns back first.",
				"sound_path": ""

			},
			"Buffet": {
				"image_path": "",

				"description": "The hallway opens up into what passes for the buffet. A long, glass counter reflects the light in soft golds and greens, warped by age and neglect.\n
	The wallpaper peels near the ceiling, and a tired potted plant leans into the window like it's trying to escape.\n
	But behind the counter, things are… alive.\n
	A small, well-dressed asian man with slicked-back hair and deep crow’s feet tends a hotplate, carefully twirling spaghetti with metal tongs like it’s a delicate art. The steam rises slowly, quietly.\n
	To the side, a tall woman in a starched apron carves ham with practiced speed, her thick Russian accent slicing through the quiet each time she asks, 'Next?'\n
	Nobody’s speaking much. The food smells fine. It looks fine. But the whole room feels like a performance running just a beat too slow. Like everyone involved knows the lines, but forgot what they meant.\n
	Past the buffet, the dining area stretches wide under a low ceiling and soft light. The carpet is thick and patterned, muting every step. Tables are arranged in gentle, orderly rows, dressed in white linen and set with silverware that never seems to tarnish.\n
	There’s no host. No one takes your name. You simply find your place. And there’s always a place. No matter how many guests are seated, there’s always one more table waiting, clean and unclaimed.\n
	The clinking of utensils is steady but low. Conversations stay hushed, almost rehearsed. A couple near the window eats in silence. A man in a grey suit pours himself wine from a bottle that wasn’t there a minute ago.\n
	No one seems in a hurry. And though the room isn’t full, it feels occupied. Not crowded, just watched. As if the walls themselves are paying attention, just in case you forget where you are.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Blue Bonnets : Hall Centaur"],
		"characters": []
	},










###############################################################################################


################################## Montreal Nord Area ###################################


"Boulevard Industriel": {
	"zone_name": "Boulevard Industriel",
	"default_viewpoint": "main",
	"category":"montreal_high_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Boulevard Industriel sinks into itself after dark. The factories stand hollow, rust curling up their sides, dock doors left half open like yawns that never finish.\n
Weed-choked lots stretch between broken fences. The rail line murmurs low, but never stops for anyone.\n
Inside, the air tastes like metal and time. Fluorescents twitch overhead. Machinery sleeps under tarps that shift when no one’s near.\n
It’s quiet, mostly. Then something creaks. Then nothing again.\n
You were sure this place was empty. You’re less sure now.",
			"sound_path": ""

		},
		"Outside Factory 13": {
			"image_path": "",

			"description": "Factory 13 looms at the heart of the derelict industrial sector like a monument to exhaustion. Its brick skin is flaking, scabbed with rust where pipes once gleamed, and its broken windows gape like a hundred hollow eyes. The number itself—13—still stenciled in faded white above the main doors, is more curse than label, as though the place always knew what it would become.\n The warehouses flanking it are no better—long, gutted husks with roofs caved in, skeletal beams exposed against the sky. Loading docks yawn open, their ramps sagging, concrete chipped and scarred from decades of disuse. Grass pushes through fissures in the asphalt, and the air smells faintly of ash, oil, and mildew—as if the entire district is slowly rotting in place.",
			"sound_path": "" 

		 },   
		"Between the Warehouses": {
			 "image_path": "",

			"description": "The alleys stretch like veins between the hulks of abandoned warehouses, long chasms of brick and rust where sunlight dies quickly. Cracked pavement buckles under the weight of weeds pushing through, their roots blackened by oil and old runoff. The air tastes metallic, tinged with mildew and forgotten chemicals, as though the buildings still exhale the labor of another age.\n Graffiti climbs the walls in layers, words and sigils half-scrubbed away, some in scripts no one admits to knowing. Rusted pipes and fire escapes curl downward like broken ribs, their shadows quivering across puddles that never seem to dry. Rats move here in nervous bursts, as though wary of something larger, unseen.",
			"sound_path": ""  

		},
	},
	"connected_zones": ["Montréal-Nord","Factory 13"],
	"characters": []
},
# ---------- Factory 13 Zone ----------
	"Factory 13": {
		"zone_name": "Factory 13",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The factory squats at the edge of the city like a rusted carcass, its windows long since shattered, its walls tattooed with graffiti and peeling paint. Inside, the air is thick with chemical rot and the ghost of machine oil, as if the building remembers when its veins ran hot with labor. Now, instead of conveyor belts and sparks, there are only broken mattresses, scavenged couches, and bodies slumped in shadows.\n A single lantern flickers where the roof leaks, light trembling across faces gaunt and hollow-eyed. Pipes drip steadily, their rhythm joining the low murmur of whispers—though not all belong to the living. Some corners hum faintly, as though voices are caught in the walls, carried along rusted ducts that once fed machines.\n The addicts drift in and out of stupor, but their nodding heads sometimes turn in unison, as though listening to something beneath the drone of their own breath. Shadows move too easily across the floor, stretching like fingers, curling over bare ankles. In the dark beyond the lantern, a draft stirs with the scent of iron and damp stone—not from the factory, but from somewhere deeper, somewhere below.\n Those who stay too long claim to see lights sparking in the rafters, blue and insectile, flaring like the memory of welding torches. Others whisper that the walls throb faintly, as if the factory were still alive, feeding on the lives squandered here. Nobody leaves unchanged: some stagger out with hollow eyes, muttering prayers to gods they never believed in; others never make it to the door, claimed by the silence that waits between each drip of the leaking pipes.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Boulevard Industriel"],
		"characters": []
	},

############################ Old Montreal ######################

	"Old Montreal": {
		"zone_name": "OldMontreal",
		"default_viewpoint": "main",
		"category":"montreal_high_outside",
		"is_neighborhood": true,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Old Montreal doesn’t sleep. It waits. Quietly. With precision.\n
	The streets are narrow and ceremonial, lined with facades too symmetrical to be human. Stone and brick arranged like commandments. Balconies twist in cold flourishes. Gas lamps cast soft halos through rising mist. Neon from the port seeps across the windows, smearing false color on old-world geometry. It looks preserved. It feels enforced.\n
	Beneath your feet, the paving stones click in patterns that don’t repeat. You hear church bells from two directions, ringing out of sync. Latin inscriptions blur under moss and rain. You read them anyway. You’re not sure why. The river murmurs against the edge of the city, but the real tide is in the walls.\n
	There is no skyline here, only hierarchy. The cathedrals loom without metaphor. The courts have weight even when empty. Somewhere behind those windows, there are still names being spoken in dead dialects. Paper trails older than you snake through vaults that never open. Everything has been signed already. You’re just walking through the aftermath.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Rue Saint Pierre", "Lachine Canal", "Downtown Montreal", "Pointe-du-Moulin", "Centre-Sud", "Sud-Ouest", "Lachine"],
		"characters": []
	},
# -------------- Notre Dame Basilica ------------------
	  "Notre-Dame Basilica Forecourt (Place d'Armes)": {
	"zone_name": "Notre-Dame Basilica Forecourt (Place d'Armes)",
	"default_viewpoint": "main",
	"is_neighborhood": false,
	"viewpoints": {
	  "Main": {
		"image_path": "",

		"description": "The façade of Notre-Dame Basilica still wears its old Gothic confidence, twin towers squared against the winter sky, stonework carved for saints and civic pride. That legacy has been overwritten with a new language of light. Crimson flood-illumination clings to arches and recesses, turning snow to pale ash and the entryways into wounds of red glass. The statues in their niches remain in place, but the shadows around them have grown sharper, as if the building has learned to hold its breath. Blue streetlamps and drifting snow make the front steps look staged for ritual procession, not worship.\n\nThe main doors no longer yield to keys alone. The threshold recognizes a spoken claim. The phrase is simple, blunt, and absolute: \"power.\""
	  }
	},
	"connected_zones": ["The Nave (La Nef)", "West Tower (Perseverance)", "East Tower (Temperance)", "Old Montreal Underground (Tunnels)", "Old Montreal"],
	"characters": [],
	"secret_entry_passwords": ["power"],
	"accessible_from_zones": ["Old Montreal","Old Montreal Underground (Tunnels)"]
  },

  "The Nave (La Nef)": {
	"zone_name": "The Nave (La Nef)",
	"default_viewpoint": "Main",
	"is_neighborhood": false,
	"viewpoints": {
	  "Main": {
		"image_path": "",

		"description": "The nave was built to make the human voice small. Vaulted ceilings rise into a painted night-sky, and stained glass hangs like frozen flame above dark wood and carved railings. What used to be devotional ornament has been made strategic. Banners in deep red and black interrupt the old palette, and sigils have been worked into the visual noise with enough subtlety to pass as decoration from a distance. The central aisle runs like a measured corridor of power, its carpet patterned with geometric seals that look too deliberate to be merely aesthetic. The pews remain, but they read as seating for witnesses, not congregants. The space is still sacred in structure, but its purpose has shifted from salvation to jurisdiction.",
		"sound_path": ""

	  }
	},
	"connected_zones": ["Notre-Dame Basilica Forecourt (Place d'Armes)", "The Ceremonial Altar and the Ambo", "West Stairwell", "West Tower (Perseverance)", "East Tower (Temperance)"],
	"characters": []
  },
 
"The Ceremonial Altar and the Ambo": {
	"zone_name": "The Ceremonial Altar and the Ambo",
	"default_viewpoint": "main",
	"is_neighborhood": false,
	"viewpoints": {
	  "main": {
		"image_path": "",

		"description": "The altar once served as an endpoint for prayer. It now functions as an instrument panel for ceremony. Gothic tracery frames the dais in an aggressive geometry, and the candlelight has been tuned toward theatrical contrast rather than warmth. A cold blue focal glow isolates the central reliquary space, making the surrounding reds and blacks look like dried lacquer. Figures carved into the architecture remain, but their silhouettes read more like sentinels than saints. The ambo stands nearby as a platform for doctrine, testimony, and condemnation. Symbols circle the floor and climb the vertical surfaces in repeating motifs, not painted as graffiti, but integrated as if the room grew them over time. This is not a desecration by vandalism. It is a takeover by redesign."
	  }
	},
	"connected_zones": ["The Nave (La Nef)","West Stairwell"],
	"characters": []
  },
  
"West Stairwell": {
	"zone_name": "West Stairwell",
	"default_viewpoint": "West Stairwell",
	"is_neighborhood": false,
	"viewpoints": {
	  "West Stairwell": {
		"image_path": "",

		"description": "A carved wooden stair curls upward in a tight spiral, polished by time, then scarred by intent. The railings carry circular stamps and etched marks that look like ornamental medallions until the eye catches their repetition and precision. Columns and carved supports crowd the space, turning a simple ascent into a corridor of occlusion and angles. Above, the architecture compresses into shadowed balconies and latticework, where a watcher can stay unseen without needing to hide. The red-blue lighting cuts across wood and stone like stage-light across a set, and the stair becomes a ritual path disguised as maintenance access. It is functional, defensible, and designed to keep movement predictable."
	  }
	},
	"connected_zones": ["The Nave (La Nef)", "The Ceremonial Altar and the Ambo", "West Tower (Perseverance)"],
	"characters": []
  },

"West Tower (Perseverance)": {
	"zone_name": "West Tower (Perseverance)",
	"default_viewpoint": "West Tower (Perseverance)",
	"is_neighborhood": false,
	"viewpoints": {
	  "West Tower (Perseverance)": {
		"image_path": "",

		"description": "The West Tower, Perseverance, was built to hold bells and wind, to broadcast faith over Old Montréal. Under new ownership it has been reorganized into a vertical laboratory of devotion-by-method. Lower levels serve as intake and sorting, where artifacts, documents, and instruments are catalogued and stripped of their comforting narratives. Mid-level chambers function as study rooms and controlled ritual spaces, where chalk circles share floor-space with equipment cases and locked cabinets. Upper levels are reserved for observation and signal work, including listening posts over the city and the careful curation of messages carried by sound. The tower’s purpose is not simply occult. It is investigative. It treats mystery as a resource and keeps it under inventory."
	  }
	},
	"connected_zones": [ "The Nave (La Nef)", "West Stairwell", "The Crypt Gate (Access)"],
	"characters": []
  },

  "East Tower (Temperance)": {
	"zone_name": "East Tower (Temperance)",
	"default_viewpoint": "East Tower (Temperance)",
	"is_neighborhood": false,
	"viewpoints": {
	  "East Tower (Temperance)": {
		"image_path": "",

		"description": "The East Tower, Temperance, was once a housing for bells and ceremonial resonance. Its new arrangement is disciplined violence dressed as order. Lower rooms function as armory and issuance, with racks, lockboxes, and secured storage integrated into old stone alcoves. Training spaces occupy the tower’s broader interior segments, where footwork drills and restraint practice replace choir processions. Interrogation is handled in rooms that preserve the building’s acoustics, turning stone into a tool. The upper reaches become a watch and response node, with controlled access points and pre-planned routes down into the basilica. Temperance is not mercy here. It is control, measured force, and the refusal to waste motion."
	  }
	},
	"connected_zones": [ "The Nave (La Nef)","Notre-Dame Basilica Forecourt (Place d'Armes)","The Crypt Gate (Access)"
	],
	"characters": []
  },

  "The Archive Vault": {
	"zone_name": "The Archive Vault",
	"default_viewpoint": "The Archive Vault",
	"is_neighborhood": false,
	"viewpoints": {
	  "The Archive Vault": {
		"image_path": "",

		"description": "This room reads like a contradiction built on purpose. Warm wood, crowded shelves, and a working desk suggest scholarship, but the clutter is curated, not casual. Papers are stacked as if they were triage, books shelved as if they were ammunition, and the lighting is chosen to preserve detail rather than comfort. The ceiling hangs low, compressing the space into something private and operational.\n\nThe entrance mechanism does not accept brute force. It accepts recognition. A single word is used as the key, spoken like a seal placed on the air.\n The vault is sealed tight. A code and a key is needed to get in side. Makes one wonder what  is so important?

Once inside, the area is filled with books, items, and trinkets. The most mundane pieces are in glass cases. 

A Brown Leather Jacket 
Tyrant of the Pyre
Malik the Red

A painted letter with bright yellow flowers that almost move in the light.
The Last of the Wheatfield Crows
Masie and Liam

A giant diamond ring with a white gold band
Senoi the Blinding Light.
Evelyn",
	  }
	},
	"connected_zones": ["West Tower (Perseverance)","The Crypt Gate (Access)"
	],
	"characters": [],
	"secret_entry_passwords": ["Intrare"],
	"accessible_from_zones": ["West Tower (Perseverance)","The Crypt Gate (Access)"]
  },

  "The Crypt Gate (Access)": {
	"zone_name": "The Crypt Gate (Access)",
	"default_viewpoint": "The Crypt Gate (Access)",
	"is_neighborhood": false,
	"viewpoints": {
	  "The Crypt Gate (Access)": {
		"image_path": "",

		"description": "Behind an unremarkable threshold, the basilica’s under-level access is sealed by a door that belongs to banks, not churches. Its mechanisms are exposed like anatomy, metal ribs and hinges engineered for refusal. Inside the open frame sits a second barrier of vertical iron bars, ornamental in pattern and absolute in function. The wood beyond it looks old and polished, the kind of surface that suggests repeated handling by people who understood procedure. This gate does not announce itself as a secret. It announces itself as a policy. Whatever lies below is not hidden by myth. It is protected by design."
	  }
	},
	"connected_zones": [ "West Tower (Perseverance)","East Tower (Temperance)", "Old Montreal Underground (Tunnels)"],
	"characters": []
  },

  "Old Montreal Underground (Tunnels)": {
	"zone_name": "Old Montreal Underground (Tunnels)",
	"default_viewpoint": "Old Montreal Underground (Tunnels)",
	"is_neighborhood": false,
	"viewpoints": {
	  "Old Montreal Underground (Tunnels)": {
		"image_path": "",

		"description": "Beneath the streets, Old Montréal turns into brickwork and seepage. Moss crawls along mortar lines, water threads from broken seams, and the air settles into a damp equilibrium that never fully changes. The corridor is tight, practical, and old enough to have held more than one era’s secrets. A bricked archway blocks one direction like a surgical stitch, implying that the tunnel network has been edited over time, not merely abandoned. This is not the bright commercial underground of the modern city. This is the older underside, built for utility, escape, and quiet movement between places that prefer not to be connected on a map."
	  }
	},
	"connected_zones": ["Notre-Dame Basilica Forecourt (Place d'Armes)", "The Crypt Gate (Access)", "Underground City"],
	"characters": []
  },

  "Zarrath's Haven (Lower Level Suite)": {
	"zone_name": "Zarrath's Haven (Lower Level Suite)",
	"default_viewpoint": "main",
	"is_neighborhood": false,
	"viewpoints": {
	  "main": {
		"image_path": "",

		"description": "The haven is carved out of stone like a private annex to the underworld, part cell, part command room. A ritual circle burns red across the floor in clean lines, not smeared, not improvised. A desk and aging computer equipment sit inside the same space as candles and ward-markings, technology and sorcery forced into cooperation. The furniture is modest but deliberate, chosen for utility and personal taste rather than luxury. A bed occupies the back wall beneath arching stone, while secured storage and staged equipment suggest that rest here is permitted, not assumed.\n\nEntry is controlled by a phrase treated as doctrine. The word used is not a request and not a greeting. It is a claim: \"sovereignty.\"",
		"sound_path": ""

	  }
	},
	"connected_zones": ["The Crypt Gate (Access)","Old Montreal Underground (Tunnels)" ],
	"characters": [],
	"secret_entry_passwords": ["Soverignty"],
	"accessible_from_zones": ["The Crypt Gate (Access)","Old Montreal Underground (Tunnels)"]
  },

# ---------- The Red Tavern Zone ----------
	"The Red Tavern": {
		"zone_name": "The Red Tavern",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A long wooden bar stretches across the room, its surface scarred with knife marks, rings, and dents from decades of rough use. The wood is dark, unevenly polished, and patched in places where boards have split or warped. Behind the counter, tall shelves built from mismatched planks hold rows of dusty bottles, chipped glasses, and old metal canisters.
The room’s walls are paneled with aged, water-stained wood reinforced by exposed beams and black iron brackets. The ceiling is low, crowded with hanging cables, thick pipes, and a loose network of chains woven between the rafters. Several dim yellow lamps swing from their mounts, casting soft cones of light across the stools lined up at the bar. The floor is cracked concrete with dark discolorations embedded into its surface, giving the entire space a worn, lived-in look. A narrow staircase descends from this room into the depths of the Red Ring.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Red Ring (Main Arena)", "The Red Chamber","Old Montreal"],
		"characters": [],
		"secret_entry_passwords": ["Redpass"],
		"accessible_from_zones": ["Old Montreal"]
	},

# ---------- The Red Ring (Main Arena) Zone ----------
	"The Red Ring (Main Arena)": {
		"zone_name": "The Red Ring (Main Arena)",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A massive octagonal pit dominates the chamber, its concrete floor cracked, worn, and stained in dark, irregular patterns. The cage walls are made of thick, rusted chain-link fencing reinforced with welded steel bars and heavy anchor plates bolted into the stone foundations. The walkways around the cage are grated metal platforms, scuffed and dented, with patches of corrosion spreading along the railings.
Above, a tangle of industrial chains and exposed piping hangs from the ceiling like a metal canopy, crisscrossing between support beams. Harsh overhead floodlights throw sharp angles of light downward, leaving the edges of the room in darkness. Concrete walls are scarred, gouged, and scorched, with faded graffiti and old posters peeling in layers. The air holds the cold, metallic scent of iron and old damp concrete.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Red Tavern", "Markus' Room", "The Red Chamber"],
		"characters": []
	},

# ---------- The Red Chamber Zone ----------
	"The Red Chamber": {
		"zone_name": "The Red Chamber",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Rough-cut stone walls encircle the chamber, each surface etched with aged carvings, scratched markings, and soot-blackened sigils. The floor is uneven stonework, broken in places and patched with mismatched slabs. Iron braziers sit on tripods near the edges of the room, filled with ash and melted remnants of past burnings.
A long stone table stands at the chamber’s center, heavy and monolithic, its edges chipped and its surface worn smooth by years of use. Wooden stools, crates, and small piles of ritual objects — candlesticks, metal cups, crude reliquaries, and clay urns — clutter the edges of the space. Thick chains coil from the ceiling beams overhead, some hanging loosely like iron vines. Dim amber lanterns mounted along the walls cast slow-moving shadows across the room.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Red Tavern", "The Red Ring (Main Arena)", "Markus' Room"],
		"characters": []
	},

# ---------- Markus' Room Zone ----------
	"Markus' Room": {
		"zone_name": "Markus' Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A compact, private room hidden behind reinforced doors and connected by a narrow corridor from the Ritual Chamber. The space is built from thick stone and concrete, giving it a bunker-like feel. A modest bed sits in the corner, its frame metal and utilitarian, with a heavy, dark blanket thrown over it.
A small desk stands opposite the bed, cluttered with notebooks, old books, maps, and various objects collected over time. The walls are a mixture of bare stone and sections of patched plaster where cracks have spread like thin spiderwebs. Wooden shelves line one wall, filled with tools, spare clothing, and a small selection of personal items.
A single industrial lamp hangs overhead, its metal shade dented and its chain mount slightly crooked, casting a warm, concentrated pool of light in the otherwise dim room. The floor is rough, cold concrete, scattered with a few rugs that have long since faded and frayed at the edges.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Red Ring (Main Arena)", "The Red Chamber"],
		"characters": []
	},

# ---------- Librairie Bertrand Zone ----------
	"Librairie Bertrand": {
		"zone_name": "Librairie Bertrand",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Quiet, the scent of paper & ink floods into your nose. The building holds a ginger warmth, a reminder of the day before in it. English & French books line the shelves in equal measure. With long halls of bookshelves & large open windows that bare its interior fully to the outside world. For those who'd call themselves Cainites, it reeks of a lack of privacy. The only hope to feed being tired people in the night or those perusing late at night. 

Sometimes an attendent can be rarely seen on the weekends, though they largely pay people no mind as long as no visible crimes or attempted theft is being undertaken.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Rue Saint Pierre"],
		"characters": []
	},

# ---------- Librairie Bertrand Basement Zone ----------
	"Librairie Bertrand Basement": {
		"zone_name": "Librairie Bertrand Basement",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "It's a little warm down here, though not damp. Books tower around you, all collections & older books that need protecting, things that are actually considered valuable. It's finely kept, but eerily silent, if one looks amongst some of the bookshelves. Jars of teeth can be found, a small storage closet holds a vacuum, a broom & has a floor of bloodstained black brick.

A singular drain lies the center of it, looking recently installed. It does not take a genius to figure out something is WRONG here.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Librairie Bertrand"],
		"characters": [],
		"secret_entry_passwords": ["Penknife"],
		"accessible_from_zones": ["Librairie Bertrand"]
	},

# ---------- Saint-Pierre-Apôtre Church Zone ----------
	"Saint-Pierre-Apôtre Church": {
		"zone_name": "Saint-Pierre-Apôtre Church",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Countless people flood this Roman Catholic church, there's a frenetic energy to the place. The gloom that characterizes Rue Saint Pierre feels so far away when one enters. A newly constructed bell tower that rings out in triumph. A church of thirty six stained glass windows, a church dedicated to Saint Peter. 

A church that has been declared?

O p e n.

Everyone welcomed: remarried, divorced or homosexual. Brunches are held after mass, workshops offered on queer themes & what had seemed to many to be a controversial choice. Feels already like it was the only right choice, amongst a city that suffocates many kine feel like they can finally breathe within these walls.

While Cainites feel uncomfortable, in a place where faith abounds bright & strong.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Rue Saint Pierre"],
		"characters": []
	},

# ---------- Rue Saint Pierre Zone ----------
	"Rue Saint Pierre": {
		"zone_name": "Rue Saint Pierre",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Once the 'Wall Street' of Montreal, built over the Saint Pierre river. This busy throughfare was the heart of old Montreal & is still a significant part of the Lower Town. Yet a gloom hangs over it, an uncertainty as bankers & shopkeepers steadily trickle out. As the last of the Industrial elements of what was once one of the most important parts of the city fade into irrelevance. 

Rue Saint Pierre finds its opulent historical shops & buildings being transformed into apartments. Finds itself turning from everything, a place of power into a place defined by its subservience to others. 

Newly opening Hotels are being stuffed with tourists, restaurants dandy out mockeries of Montreals culture to the gullible. While countless turn to faith, as the churches power rises. Saint-Pierre-Apôtre Church is newly renovated, filling its pews with any & all, inclusive where other Roman Catholics might turn some away.

To all Cainites, a nagging feeling might be scratching at them. With this change comes a power vacuum, one that it feels something besides them is filling. Faith might not yet be dead in a street named for a Saint.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Librairie Bertrand", "Saint-Pierre-Apôtre Church", "Old Montreal"],
		"characters": []
	},


# ---------- Hotel Exterior Zone ----------
	"Hotel Soleil Levant Exterior": {
		"zone_name": "Hotel Soleil Levant Exterior",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This grand hotel looms above the street like a relic from another age. Its stone façade, once pristine, is now weather worn, and marred by the slow creep of ivy. Rows of tall, dark windows stare blankly outward, gaping maws that reveal nothing of the interior.

Above the entrance, a neon sign written in elegant cursive bears the name Le Soleil Levant. The letters sputter faintly, buzzing like dying insects. In the center of the sign, a small sun icon hangs crooked, its bulbs long burnt out; just one more broken promise,

Though the street outside bustles with life, the space directly in front of the hotel always seems quiet, as if sound itself refuses to linger near the threshold.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Old Montreal", "Hotel Soleil Levant Lobby"],
		"characters": [],
		"secret_entry_passwords": ["Welcome"],
		"accessible_from_zones": ["Old Montreal"]
	},

# ---------- Hotel Lobby Zone ----------
	"Hotel Soleil Levant Lobby": {
		"zone_name": "Hotel Soleil Levant Lobby",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The cavernous lobby stretches out in all directions. A picture of luxury left to decay. The onyx and marble mosaic covering the floor swirls in patterns that seem to shift when you look away, pulling the eye toward the sweeping staircases that ascend into shadow. 

A dilapidated fountain marks the center of the space, though its flow has slowed to a quiet trickle, and the marble statuette within has long since toppled over, pieces scattered throughout the basin.

High above, the ceiling, once painted to look like the night sky, has now begun to crack and peel, gold-leaf stars gleaming like watchful eyes. A few chandeliers still hang, providing the space with light, though the glow feels cold and sterile.

The atmosphere is hushed, expectant, as though every footstep is being judged.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant Exterior", "Hotel Soleil Levant Conference Room", "Hotel Soleil Levant Pool Room","Hotel Soleil Levant Ballroom" ],
		"characters": []
	},

# ---------- Hotel Conference Room Zone ----------
	"Hotel Soleil Levant Conference Room": {
		"zone_name": "Hotel Soleil Levant Conference Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A long, wooden table stretches through the murky room. High backed chairs surround the table, and are themselves surrounded by a heavy darkness that the lone lamp hanging from the ceiling is unable to pierce. The table’s polished surface is disturbed by a single deep gouge that runs through its center towards the chair placed at its head, farthest from the door.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant Lobby"],
		"characters": []
	},

# ---------- Hotel Soleil Levant Pool Room Zone ----------
	"Hotel Soleil Levant Pool Room": {
		"zone_name": "Hotel Soleil Levant Pool Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The pool’s empty basin stretches like an open grave through the middle of the room. The tiles faded and cracked in places, with stubborn dark stains spotted here and there. Around the edge is a velvet rope, half rotted away, with a gap just in front of the rusted ladder that serves as the pool’s sole entrance. An eclectic assortment of chairs ring around the outside of the barrier to form a spectating area.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant Lobby"],
		"characters": []
	},

# ---------- Hotel Elevator Zone ----------
	"Hotel Soleil Levant Elevator": {
		"zone_name": "Hotel Soleil Levant Elevator",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The elevator looks like it’s survived decades without a proper upgrade. The doors wheeze open unevenly, one side always lagging behind the other, revealing a cramped box lined with wood paneling that’s gone dull and scuffed. The brass rail is sticky to the touch, its shine long since rubbed away. The carpet underfoot is threadbare at the center, the pattern worn down to a flat gray, with faint stains that never seem to come out. A single fluorescent bulb buzzes overhead, casting a sickly glow that makes the space feel smaller than it is. The buttons are scratched, some with their numbers worn almost smooth, and a few light up weakly as though they’re struggling to stay alive. Every time the elevator lurches into motion, it shudders and rattles just enough to remind you it hasn’t been inspected in a while.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant Lobby","Hotel Soleil Levant Basement","Hotel Soleil Levant 13th Floor"],
		"characters": [],
		"secret_entry_passwords": ["goingup"],
		"accessible_from_zones": ["Hotel Soleil Levant Lobby", "Hotel Soleil Levant Basement","Hotel Soleil Levant 13th Floor"]
	},
	
# ---------- Hotel Soleil Levant Guest Floor Zone ----------
	"Hotel Soleil Levant Guest Floor": {
		"zone_name": "Hotel Soleil Levant Guest Floor",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The hallways of the old hotel stretch far in every direction, their patterned carpets swallowing footsteps to maintain a deathly silence. With so many identical doors, it’s impossible to tell just how many rooms are occupied, and how many sit empty, waiting for new arrivals.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant Lobby"],
		"characters": []
	},

# ---------- Hotel Soleil Levant 13th Floor Zone ----------
	"Hotel Soleil Levant 13th Floor": {
		"zone_name": "Hotel Soleil Levant 13th Floor",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The hidden, unlucky floor of the hotel hides not only glamour but horror from the rest of the building; this is where the Pack lives, each door assigned to an official member of Les Affreux.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant Elevator"],
		"characters": []
	},
	
# ---------- Serah's Private Suite Zone ----------
	"Serah's Private Suite": {
		"zone_name": "Serah's Private Suite",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A heavy scent of parchment and candle wax hangs in the air. The walls are lined with bookshelves, their spines worn with subjects ranging from anatomy to obscure occult treatises. A writing desk stands beneath an oil lamp, its surface littered with quills, scalpels, and half-filled journals written in a precise, clinical hand. Across from it, starkly contrasting the scholarly order, are devices of restraint and torment, steel and leather, polished to a gleam, their presence as deliberate as the tomes. The room feels like a lecture hall and a chamber of cruelty combined, a study where blood and philosophy intermingle without apology.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant 13th Floor"],
		"characters": [],
		"secret_entry_passwords": ["oingoboingo"],
		"accessible_from_zones": ["Hotel Soleil Levant 13th Floor"]
	},

# ---------- Hotel Soleil Levant Ballroom Zone ----------
	"Hotel Soleil Levant Ballroom": {
		"zone_name": "Hotel Soleil Levant Ballroom",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Once a stage for glittering galas, the ballroom is cavernous and still. The crystal chandeliers above sway with no draft, scattering fractured light across the cracked parquet floor. Faint strains of music sometimes drift through, an orchestra playing from nowhere, cut off abruptly when you strain to listen. The long banquet tables are covered in dusty white cloths that ripple faintly as though something stirs beneath them.
",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant Lobby"],
		"characters": []
	},


# ---------- Hotel Soleil Levant Penthouse Zone ----------
	"Hotel Soleil Levant Penthouse": {
		"zone_name": "Hotel Soleil Levant Penthouse",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "At the very apex of the hotel is its crown jewel. The penthouse is both grand and terrible. Beautifully carved pillars hold the arched ceiling aloft. The furnishings reflect two very different tastes. One half of the room is sparsely appointed with practical accommodations. The other is crowded with lavish, artful designer pieces. 

The two halves converge in the middle, where a raised, dais-like platform supports a large bed, an elegant dining table placed just before it.

Overlooking everything is a giant stained-glass window. The thick red panes serve to protect the room’s inhabitants from the sun’s rays, but also leave the entire area bathed in a bloody glow at all hours.
",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant Elevator"],
		"characters": [],
		"secret_entry_passwords": ["darksun"],
		"accessible_from_zones": ["Hotel Soleil Levant Elevator"]
	},
	
	
# ---------- Hotel Soleil Levant Basement Zone ----------
	"Hotel Soleil Levant Basement": {
		"zone_name": "Hotel Soleil Levant Basement",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The basement is a concrete maze of twisting corridors and rusted pipes. The lightbulbs overhead are never enough to truly illuminate the space, and constantly emit a low, electric whine. The air feels heavy, oppressive, like a tomb opened for the first time in centuries. Dark stains mark the floor here and there, and in the stillness some swear they've heard a slow, heavy thudding, like insistent knocks on an unseen door.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hotel Soleil Levant Elevator"],
		"characters": []
	},
	
"Pointe-du-Moulin": {
	"zone_name": "PointeDuMoulin",
	"default_viewpoint": "main",
	"category":"",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Something is wrong at the edge of the island.\n
Pointe-du-Moulin stretches into the river like it’s trying to escape the city. The land is landfill and bone, poured out in unnatural shapes. Wind moves in loops. Fog rolls in from the canal and never leaves. Warehouses stand too tall, too narrow, windows too dark to reflect anything. Their doors are chained shut, but still rattle at night. The silence here feels constructed, like someone killed the sound on purpose.\n
You walk five minutes in and forget what direction you came from. Footsteps echo when you stop. Light posts flicker in patterns that don't match the power grid. Dogs refuse to follow past the rail cut. People say it’s just old industrial space, but no one comes here twice without changing something in their face. The peninsula holds its breath. It knows you don’t belong. And it’s waiting for you to realize it.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Silo No. 5", "Lachine Canal", "Old Montreal", "Sud-Ouest"],
	"characters": []
},


"Silo No. 5": {
	"zone_name": "SiloNo5",
	"default_viewpoint": "main",
	"category":"",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Across the water from Old Montreal, it waits.\n
Silo No. 5 breaks the view like a warning carved into the skyline. Behind the tourist shops and wedding photographers, it sits on the far shore, massive and silent, refusing to disappear.\n
People ask what it is, but no one really knows. It was built to hold something. It still does. The grain is long gone, but the weight remains.\n
Its walls are mottled with rust and old salt, streaked like a corpse left out in the rain. Dozens of sealed doors mark its skin like surgical scars. Catwalks lead to nowhere. Windows reflect no light.\n
The building does not seem abandoned. It seems contained.\n
From across the water, it feels dormant, but not dead. And if you look long enough, a thought starts to form that doesn’t feel like your own. Something is inside. Something that remembers being full.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Pointe-du-Moulin"],
	"characters": []
},


	"Saint-Michel Metro – Exterior": {
		"zone_name": "SaintMichelMetroExterior",
		"default_viewpoint": "main",
		"category":"montreal_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The end of the line. The concrete here feels heavier.\n
	Rust crawls down the walls. Tags layer like old bruises. A single streetlamp buzzes overhead, flickering in slow panic.\n
	The stairs sink into the ground, wet around the edges. Something hums below, low and constant, like breath through a cracked mask.\n
	A man stands near the railing, smoking nothing, watching nothing. His jacket hasn’t moved in minutes.\n
	Buses hiss, pause, move on. No one lingers. Not here. The metro waits with its mouth open, patient and damp.\n
	Not a station. A stop.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Saint-Michel", "Saint-Michel Metro", "North Metro Maintenance Tunnels"],
		"characters": []
	},

	"Saint-Michel Metro": {
		"zone_name": "SaintMichelMetroLine",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Bleu qui penche, bleu sans bord,\n\
	train fantôme, souffle mort.\n\
	Les horloges fondent en vapeur,\n\
	le temps s'effiloche dans la peur.\n
	Un chant grince sous les néons,\n\
	appel perdu, faux horizon.\n\
	Nul départ, nul appareil,\n\
	juste le bleu,\n\
	et son sommeil.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Bonaventure Metro", "Namur Metro", "Place des Arts Metro", "Saint-Michel Metro – Exterior", "North Metro Maintenance Tunnels"],
		"characters": []
	},

	"Bonaventure Metro": {
		"zone_name": "BonaventureMetro",
		"default_viewpoint": "Entrance",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"Entrance": {
				"image_path": "",

				"description": "The Bonaventure Metro entrance lies buried in stone and tired neon, a hollowed space built only to be used.\n
	Opened in 1967 to link the new towers to the veins of the city, it was never meant to dazzle.\n
	No signs boast of destinations. No architecture tries to impress.\n
	The lights hum overhead, the tiled floor echoes under passing footsteps, and the station breathes quietly in the dark, doing its work without pride and without thanks.",
				"sound_path": ""

			},
			"line": {
				"image_path": "",

				"description": "[b]Sous Gauchetière[/b]\n
	Je chante bas sous vos trottoirs,\n\
	où dorment pierres et vieux miroirs.\n\
	Sous mille pas, sous mille tours,\n\
	je porte encore vos jours trop lourds.\n
	Personne ne voit, personne n'entend,\n\
	le souffle usé d'un Montréal vivant.\n\
	Je creuse ma voix dans vos détours,\n\
	et j'oublie vos promesses d'amour.",
				"sound_path": ""

			}
		},
		"connected_zones": ["1000 de la Gauchetière", "Namur Metro", "Place des Arts Metro", "Saint-Michel Metro", "South Metro Maintenance Tunnels"],
		"characters": []
	},

# ---------- B.I.T.E Community Center Zone ----------
	"B.I.T.E. Community Center": {
		"zone_name": "B.I.T.E Community Center",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "B.I.T.E Community Center was established for the entire community to gather and receive help/services. It runs a variety of programs from the former school building, including job assistance programs, bail assitance programs, a drug rehab clinic, AA meetings, and much more. Established by the Godbold family, who also run a soup Kitchen in Saint-Leonard, many of those less fortunate take advantage of the services and the general lack of judgement the staff here seem to hold toward them.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Montréal-Nord", "B.I.T.E. Community Center: Interior"],
		"characters": []
	},
	
# ---------- B.I.T.E. Community Center: Office Zone ----------
	"B.I.T.E. Community Center: Office": {
		"zone_name": "B.I.T.E. Community Center: Office",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The office of an overworked administrator. The name 'Jerry Smolecki' stands out on a little carved wooded namplate, half hidden under scattered manila folders.",
				"sound_path": ""
			},
		},
		"connected_zones": ["B.I.T.E. Community Center: Interior"],
		"characters": []
	},

# ---------- B.I.T.E. Community Center: Interior Zone ----------
	"B.I.T.E. Community Center: Interior": {
		"zone_name": "B.I.T.E. Community Center: Interior",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The community center attempts to cultivate a clean and functional aesthetic, the bulletin boards that decorate the halls covered in mutual aid posters, union information, suicide assistance hotlines, and much more.

The main hall connects to all the important parts of the center - the clinic, the main office, the community rec-room, and multiple activity rooms. Part of the building still remains sectioned off for renovations.",
				"sound_path": ""
			},
		},
		"connected_zones": ["B.I.T.E. Community Center", "B.I.T.E. Community Center: Office", "B.I.T.E. Community Center: Basement", "B.I.T.E. Community Center: Clinic"],
		"characters": []
	},
# ---------- "B.I.T.E. Community Center: Basement" Zone ----------
	"B.I.T.E. Community Center: Basement": {
		"zone_name": "B.I.T.E. Community Center: Basement",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The B.I.T.E. basement is crowded and full of utility access, pipes, furnaces, and electrical panels. It is dark and dank, noticeably more stiffing in the air than the rest of the building.",
				"sound_path": ""
			},
		},
		"connected_zones": ["B.I.T.E. Community Center: Interior"],
		"characters": []
	},

# ---------- "B.I.T.E. Community Center: Clinic" Zone ----------
	"B.I.T.E. Community Center: Clinic": {
		"zone_name": "B.I.T.E. Community Center: Clinic",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The drug clinic seeks to help addicts reform their lives with the rehabilative power of community support. Both bail assistance and job-training programs are available so long as attendees remain on-site for the duration of the program.",
				"sound_path": ""
			},
		},
		"connected_zones": ["B.I.T.E. Community Center: Interior"],
		"characters": []
	},

"Sainte-Gertrude Church": {
  "zone_name": "SainteGertrudeChurch",
  "default_viewpoint": "Main",
  "category": "montreal_high_outside",
  "is_neighborhood": false,
  "viewpoints": {
	"Main": {
	  "image_path": "",

	  "description": "The Sainte-Gertrude Church rises from the neighborhood like something left behind by an older version of the city.\nIts white stone façade has dulled to the color of old teeth. The bell tower still stands straight, but the bells do not ring. Not anymore.\nThe grounds feel empty even during the day. The hedges are trimmed but never fresh. No cars park out front. No one walks up the steps. Lights flicker in the vestibule at odd hours, but no one opens the doors.\nPeople pass by in silence. They do not stare. They do not speak its name unless they have to.",
	  "sound_path": ""

	},
	"Rectory Lawn": {
	  "image_path": "",

	  "description": "Beside Sainte Gertrude Church lays a vacant lawn of dead grass and equally dead hopes. The dirt may be sanctified but it is as tired and weary as the other residents of Montreal Nord. It is a non-place, existing between destinations, peppered with litter from the street and the occasional ambitious clump of weeds. Behind it lays the Church rectory, solid and silent.",
	  "sound_path": ""

	}
  },
  "connected_zones": ["Sainte-Gertrude : Main Hall", "Montréal-Nord", "B.I.T.E. Community Center"],
  "characters": [],
  "secret_entry_passwords": ["Gertrude"],
  "accessible_from_zones": ["Montréal-Nord","B.I.T.E. Community Center"]
},



"Sainte-Gertrude : Main Hall": {
	"zone_name": "SainteGertrudeMainHall",
	"default_viewpoint": "main",
	"category":"",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The main hall stretches long and tall, cavernous and bone-white, as if carved from light that forgot how to shine.\n
Rows of wooden pews sag toward the center like they’ve been praying too long. Dust lingers in the air but never settles. It moves when no one walks.\n
The ceiling arches high above, smooth and unadorned. No murals, no saints. Just pale plaster, cracked at the seams.\n
A single crucifix hangs behind the altar, unlit, its figure weathered down to a suggestion.\n
The windows are stained glass, but the colors have drained from them. What remains is muted, warped. Nothing lands clean on the floor.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Sainte-Gertrude : Bunkroom", "Sainte-Gertrude : Bell Tower","Sainte-Gertrude : Lower Levels", "Sainte-Gertrude Church"],
	"characters": []
},

"Sainte-Gertrude : Bunkroom": {
  "zone_name": "SainteGertrudeBunkroom",
  "default_viewpoint": "main",
  "category": "",
  "is_neighborhood": false,
  "viewpoints": {
	"main": {
	  "image_path": "",

	  "description": "Scorch marks adorn the walls. The constant smell of ash, smoke, and old blood fill one's nostrils inside. And dust, plenty of dust. There are posters and Sabbat glyphs splattered sporadically.\n\nIt's a shared sleeping area - a side room with multiple steel cots. Some of the blankets are bloodstained. There is also a bullet riddled locker. The room feels more like a forward operating base than a home, but there are some touches of identity within. Graffiti tags. Remnants of a burned flag of some sort. A broken guitar that hasn't been touched in years.\n\nOverall, it is deliberately austere. As if purpose has been carved out from a rotting corpse of a building. No real comfort dwells here. For now.",
	  "sound_path": ""
	}
  },
  "connected_zones": ["Sainte-Gertrude : Main Hall"],
  "characters": []
},

"Sainte-Gertrude : Lower Levels": {
  "zone_name": "SainteGertrudeLowerLevels",
  "default_viewpoint": "main",
  "category": "",
  "is_neighborhood": false,
  "viewpoints": {
	"main": {
	  "image_path": "",

	  "description": "The lower levels of Sainte Gertrude are host to many monsters. Rooms split off from long, dark corridors: libraries, studies, sparring rooms, interrogation rooms, storage rooms. The air smells of mildew and purpose. This is where the Pack lives and breathes, training, learning, and turning a derelict shell into a fortress. Caged single bulb lights hang along the walls at intervals, dim but enough to find your way.",
	  "sound_path": "[rat squeaks, subtle dripping sound. Footsteps on stone.]"
	}
  },
  "connected_zones": ["Sainte-Gertrude : Main Hall", "Sainte-Gertrude : Laboratory", "Sainte-Gertrude : Training Room", "Sainte-Gertrude : Library", "Sainte-Gertrude : Bunker"],
  "characters": []
},

"Sainte-Gertrude : Ductus' Office": {
  "zone_name": "SainteGertrudeDuctusOffice",
  "default_viewpoint": "main",
  "category": "",
  "is_neighborhood": false,
  "viewpoints": {
	"main": {
	  "image_path": "",

	  "description": "A heavy, paneled dark wood door separates this room from the rest of the church, with an impressive array of locks. It is old, but not in the same way as Sainte Gertrude's.\nThe room is... sized. Neither large nor small, just a little over the line of lived in. There are no windows. Red velvet drapes and acrobat's gear flank the walls, obscuring their imperfections and creating the illusion of a theatrical stage in this forgotten corner of Montreal.\n\nMaps, circus playbills and band posters including Queen, Fleetwood Mac & Guns n' Roses are hung in prominent positions, with a large footlocker pushed against the back wall filled with aerial silks. A salvaged metal desk sits in the center of the room, cold and practical, hosting a computer; a complete opposite of it's owner, at least at first glance. A wheeled leather executive chair sits behind it in silent command of the room, watchful and waiting.",
	  "sound_path": ""
	}
  },
  "connected_zones": ["Sainte-Gertrude : Main Hall"],
  "characters": [],
  "secret_entry_passwords": ["Lighter"],
  "accessible_from_zones": ["Sainte-Gertrude : Main Hall"]
},

"Sainte-Gertrude : Bell Tower": {
  "zone_name": "SainteGertrudeBellTower",
  "default_viewpoint": "Storage",
  "category": "",
  "is_neighborhood": false,
  "viewpoints": {
	"Storage": {
	  "image_path": "",

	  "description": "It is quiet, here. The darkness presses in closely, yet still you feel exposed as the wind whistles through the broken windows on the bell platform above. A ladder leads up to your left, but to your right is yawning darkness, a place where things are dumped to be forgotten.\n\nYet someone has made a home here. A canvas tarp is anchored at two corners, creating a nest-like hammock where a hodgepodge of blankets and pillows are piled to create comfort in an otherwise comfortless place. Shielded by boxes and crates, one could almost overlook it. A camp lantern hangs above, offering meager light and an old scent of cigarettes, blood and feathers lingers in the nose.",
	  "sound_path": ""
	},
	"Tower Platform": {
	  "image_path": "",

	  "description": "From Sainte Gertrude's steeple, Montreal Nord sprawls out in all its messy glory.",
	  "sound_path": "[caw of crows, wing sounds, wind]"
	}
  },
  "connected_zones": ["Sainte-Gertrude : Main Hall"],
  "characters": []
},



# ---------- Sainte-Gertrude: Laboratory Zone ----------
"Sainte-Gertrude : Laboratory": {
	"zone_name": "SainteGertrudeLaboratory",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "The laboratory ceiling is low and oppressive, its stone walls sweating with damp, the mortar between them cracked and crumbling. The air hangs heavy with the mingled scents of rust, mildew, and something sharper—iron and rot, the unmistakable tang of opened flesh. The stone floor is uneven, leaving gaps where water pools in stagnant, dark puddles.\n\nTables stand at the center, none uniform, dragged together from mismatched sources: a butcher’s block scarred with deep cuts, a dented steel gurney with one wheel missing, a metal slab laid flat across barrels. Each is stained, the grain of the wood and the seams of the metal darkened with things that were never properly cleaned away. Overhead, naked bulbs dangle from twisted wires strung across hooks in the ceiling, their light harsh and uneven, buzzing and sputtering with each flicker. Shadows cling to the corners, stretching long over heaps of discarded tools.\n\nThe equipment is a patchwork of the stolen and the improvised—rusted bone saws beside carpentry blades, clamps meant for welding now turned to hold flesh, surgical scissors dulled from misuse. Glass jars line crude shelves made of stacked bricks and planks; some hold cloudy formalin suspensions, where pale shapes drift within, others contain only stains, residues of whatever once filled them. A refrigerator hums in the corner, scavenged from a kitchen decades past, its gasket cracked, its contents wrapped in butcher’s paper and sealed with string.\n\nAgainst one wall, a stone slab doubles as both dissection table and mortuary bed, its surface slick with condensation. Nearby, a drain in the floor gapes. The drip of water through the ceiling creates a slow, steady rhythm, like a heartbeat, echoing faintly through the chamber.\n\nThe whole place feels less like it was built than accreted—an anatomy of scavenged refuse stitched together with desperation and intent. The cellar does not whisper of science or medicine but of obsession, of experiments never meant to see daylight, of secrets carved open and left to fester beneath the stone.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Sainte-Gertrude : Lower Levels"],
	"characters": []
},

# ---------- Sainte-Gertrude: Training Room Zone ----------
"Sainte-Gertrude : Training Room": {
	"zone_name": "SainteGertrudeTrainingRoom",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "The training room feels like a fortress built out of scraps, its stone walls close and damp, the ceiling low enough that the beams overhead seem ready to press down on anyone who stands tall. The air is thick with dust, sweat, and the faint metallic tang of rust. It is a place of discipline, but also desperation—salvaged together from whatever could be found, not built to impress, only to endure.\n\nAt the center lies a crude sparring circle, the floor marked with a stark chalk line, defining the space where bruises and lessons are earned. Combat dummies stand at crooked angles—some are sandbags stuffed into duct-taped coveralls, others wooden poles wrapped in rags and leather belts, their surfaces split and scarred from countless strikes. Punching bags hang from chains bolted into ceiling beams, the chains creaking with each sway. Their canvas hides are patched with mismatched fabrics, darkened with sweat and split grain where fists and feet have landed too many times.\n\nAlong the far wall, a row of targets—plywood boards painted with rings, dented sheet metal, even traffic signs stolen long ago—bears the marks of blades and arrows.\n\nThe walls themselves are a gallery of violence: swords, axes, and makeshift weapons mounted on crude wooden racks, each one mismatched and worn. Some blades are rust-pitted, others sharpened to a hungry gleam.\n\nLanterns and bare bulbs strung haphazardly along wires cast harsh pools of light, leaving shadows to pool in the corners like silent onlookers. Every surface bears scars of use—stone chipped by thrown blades, beams splintered by wild strikes, mats stained from falls.\n\nThe room feels alive with the echoes of countless bouts: grunts, blows, and the rhythm of fists slamming into canvas. It is not a place of ceremony but of survival—a workshop of violence, born from what the world discarded, meant to turn bodies into weapons.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Sainte-Gertrude : Lower Levels"],
	"characters": []
},

# ---------- Sainte-Gertrude: Library Zone ----------
"Sainte-Gertrude : Library": {
	"zone_name": "SainteGertrudeLibrary",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "Wooden shelves, warped and sagging with age, line the pack's library walls. They are crammed with volumes bound in cracked leather and flaking vellum, their spines scrawled with gold script long dulled to tarnish. Some books are simple, bound in undecorated leather, while others are bound with strange clasps or chains as if to restrain what they contain. Stacks of loose folios sit atop the shelves in precarious towers, their edges blackened by candle flame or stained with substances that time alone cannot explain. Between them, reliquaries, ritual objects, and fragments of bone rest like forgotten bookmarks, left behind by hands that may not have been entirely human.\n\nLanterns hang at intervals, their glass darkened with soot, casting weak orange halos that cannot pierce the corners. Shadows gather thickly, stretching over the piles of manuscripts and scrolls, making the whole room seem deeper, older, than it should be. The silence is absolute, save for the soft creak of shelves settling or the occasional whisper of parchment shifting as if something unseen is turning the pages.\n\nThe atmosphere suggests not mere scholarship but devotion: this is a place where study was worship, where knowledge was dangerous and treated as sacred, where the stone itself seems to listen. Every shadow hints at a secret, every silence at a presence just beyond the edge of perception. It feels less like a library kept for people, and more like one built to keep the books themselves contained.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Sainte-Gertrude : Lower Levels"],
	"characters": []
},

# ---------- Sainte-Gertrude: Drogo's Study Zone ----------
"Drogo's Study": {
	"zone_name": "DrogoStudy",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "Off to the side, through a narrow arched doorway in the Library, lies a study chamber: a small, cloistered room with a single heavy desk of rough oak, gouged with knife marks and ink stains. Candlesticks squat on its surface, their wax melted into stalagmites and stalactites that have fused with the wood. A chair, its back cracked and repaired with wire, sits pushed slightly away, as though someone rose abruptly and never returned. On the desk lies a scattering of quills, dried bottles of ink, and a few open texts frozen mid-thought, their words written in cramped hands, illuminated with symbols that draw the eye yet feel dangerous to linger upon.\n\nA private collection dominates the shelves, with a carefully preserved copy of the Book of Nod, open on an ornate reading stand.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Sainte-Gertrude : Library"],
	"characters": [],
	"secret_entry_passwords": ["Drogo"],
	"accessible_from_zones": ["Sainte-Gertrude : Library"]
},

# ---------- Sainte Gertrude : Bunker Zone ----------
	"Sainte-Gertrude : Bunker": {
		"zone_name": "Sainte Gertrude : Bunker",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The bunk lies deep beneath the church, carved into a secondary basement level that was never meant to exist. The air is damp, unsettled, carrying the raw scent of freshly turned earth mixed with stone dust and candle smoke. Rough timber beams shore up the low ceiling, their edges still sharp from hurried sawing, and the walls are an uneven patchwork of brick, old mortar, and exposed soil where the digging broke through.



A narrow corridor leads into the chamber, where a row of iron-framed cots has been set up, their thin mattresses sagging under coarse woolen blankets. Buckets and crates serve as tables, cluttered with tin cups, stubbed candles, and a few dog-eared prayer books whose pages curl from the damp. Lantern light throws long shadows across the rough walls, shadows that bend and stretch strangely where the soil bulges inward, as though the earth is restless.

 The air here is heavy - suffocating for living things, but the undead are unaffected.

The ceiling drips in places, each drop echoing sharply in the confined dark, and the air never loses its chill. A faint hum can be felt through the stone—the vibration of the city above, blurred by distance and prayer. Yet it is quieter here than any sanctum upstairs, a silence so heavy it presses against the ears.



This place is meant for hiding, or for endurance. The bunk feels less like shelter and more like a refuge carved against inevitability, as though those who sleep here hope the church’s weight above will shield them from what moves unseen below.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Sainte-Gertrude : Lower Levels"],
		"characters": []
	},



# ---------- Sainte Gertrude : Tunnel Zone ----------
	"Sainte-Gertrude : Tunnel": {
		"zone_name": "Sainte Gertrude : Tunnel",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The tunnel begins as a narrow doorway hidden behind shelving in the church's basement bunker, the kind of place few would think to look. Its threshold is rough-hewn, stone and brick broken through by hands more desperate than careful, and beyond it lies a passage that smells of damp earth and old plaster.

The walls are uneven, patched with mismatched brick and crumbling mortar, reinforced here and there with scavenged timber that bows under the weight of what presses above. Water seeps through in thin rivulets, pooling in shallow depressions along the floor, and the air carries the metallic tang of rust mixed with mold.

The tunnel ends in another concealed hatch, this one in the school basement storage—hidden beneath warped floorboards and behind a stack of unused desks. The transition is abrupt: from raw, secret earth to the hollow reek of chalk dust and varnish, as if the passage doesn’t just connect two places, but two worlds—the sacred and the mundane, bound together by something they both sought to conceal.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Sainte-Gertrude : Lower Levels","B.I.T.E. Community Center: Basement"],
		"characters": [],
		"secret_entry_passwords": ["secrettunnel"],
		"accessible_from_zones": ["Sainte-Gertrude : Lower Levels","B.I.T.E. Community Center: Basement"]
	},

################## Downtown #######################

	"Downtown Montreal": {
		"zone_name": "Downtown Montreal",
		"default_viewpoint": "Downtown Montreal",
		"category":"montreal_high_outside",
		"is_neighborhood": true,
		"viewpoints": {
			"Downtown Montreal": {
				"image_path": "",

				"description": "They call it \"La Ville des Miracles Noires,\" The City of Black Miracles.
	A place where prayers go to die and are reborn as something sharper, something with teeth.
	Downtown Montreal leans against the dark like a bruised fighter, towers bending under old ambitions and flickering lights, the streets humming with the low, feverish pulse of a city that has already made peace with the end.
	Glass skyscrapers claw at the sky, forgotten plazas crumble between them, and the Metro murmurs below it all, carrying the city’s tired blood from station to station.
	Here, survival is a superstition, whispered by fools.
	The wise live fast, burn brightly, and carry nothing with them but the heat of their own collapse.
	Its streets stretch wide and broken, lined with neon storefronts clinging to life, while the towers above whisper deals and debts into the freezing night.
	Nobody owns this place.
	Not anymore.",

				"sound_path": ""

			}
		},
		"connected_zones": ["Dorchester Square", "Rue Sainte-Catherine","Rue de la Cathédrale", "Quartier des Spectacles", "McGill – Downtown Campus",  "Old Montreal", "Westmount", "Centre-Sud", "Sud-Ouest","Griffontown"],
		"characters": []
	},
# ---------- Griffontown Zone ----------
	"Griffontown": {
		"zone_name": "Griffontown",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",
				"description": "Griffintown is a bruised artery pulsing beneath the skin of downtown Montréal. The old Irish working-class neighborhood has been gutted by neglect and stitched back together with rusted scaffolding and flickering neon. The air smells of wet concrete, ozone, and something metallic that clings to the back of the throat.

There’s a wrongness to the rhythm of Griffintown. The pigeons have vanished. Dogs won’t bark. The few humans who walk the streets after midnight do so with glassy eyes and erratic steps, as if something beneath the pavement is whispering to them.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Downtown Montreal", "Rue Sainte-Catherine", "Rue de la Cathédrale"],
		"characters": []
	},

# ---------- Griffontown: Warehouse Zone ----------
	"Griffontown: Warehouse": {
		"zone_name": "Griffontown: Warehouse",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",
				"description": "A warehouse provided by the Pyre and the Flayed for use in the Sabbat-wide body dumping scheme. ",
				"sound_path": ""
			},
		},
		"connected_zones": ["Griffontown"],
		"characters": [],
		"secret_entry_passwords": ["bodies"],
		"accessible_from_zones": ["Griffontown"]
	},

# ---------- Quartier des Spectacles Zone ----------
	"Quartier des Spectacles": {
		"zone_name": "Quartier des Spectacles",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "In the Quartier des Spectacles, everything shimmers like a stage set, built to dazzle the eye. Neon floods façades, giant screens pulse with color, fountains leap in rhythm and the lights seem too carefully choreographed, as though the very neighborhood were performing for its audience.

But beneath the wash of brightness lies something quieter, heavier. The wide boulevards and glassy new constructions sit atop older bones—streets that once knew cabarets, vaudeville houses, and dive bars where shadows carried their own kind of rhythm. Even now, behind the LED glow, brick walls remain pitted and scarred, alleys narrow to dark throats, and some windows never open, their panes black like blind eyes.

It is a district that insists on being seen, and yet much of it seems designed to distract. The music masks the silences between buildings. The projected lights hide the dim, forgotten corners where no one lingers long. There is a sense of orchestration—every public gathering choreographed to keep you from noticing what waits behind the curtains.

Those who stray from the illuminated arteries find themselves in odd, liminal spaces: stairwells that smell of mildew and dust, where a faint draft seems to breathe against your skin; forgotten passageways linking theaters and galleries, too long, too narrow, like veins. The Quartier’s energy is real, but so is the exhaustion beneath it, like an actor’s painted smile stretched over a secret bruise.

Here, performance is not just entertainment but camouflage. The lights and music conceal the city’s darker rhythm, one that beats slowly, insistently, in the quiet corners—reminding you that every show must end, and when it does, the mask slips.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Place des Arts", "Centre-Sud", "Downtown Montreal", "Plateau Mont Royal"],
		"characters": []
	},

# ---------- Place des Arts Zone ----------
	"Place des Arts": {
		"zone_name": "Place des Arts",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Place des Arts feels like a concrete citadel planted in the middle of downtown Montreal, monumental but austere, more fortress than festival. The architecture is all sharp lines and pale, weather-stained stone, the plazas stretching wide and bare under the open sky. The fountains sputter in summer but often sit empty, their basins stained with algae, while pigeons and cigarette butts gather in their absence.

The square itself has a rawness then, a sense of urban grit. Its expanses of concrete are too broad, too exposed, leaving pedestrians small and scattered across it. At night, fluorescent streetlamps cast sickly pools of light that emphasize the emptiness more than they dispel it. The shadows of the surrounding towers creep over the plaza, and wind rushes through the open space, carrying scraps of litter in restless circles.

The theaters and halls loom over all of it—majestically, yes, but with a cold grandeur, their walls streaked with soot and their banners fading in the harsh weather. Place des Arts in this decade is a temple to high culture, but one that feels out of joint with its surroundings, aloof amid the changing downtown. Concert-goers in fine clothes slip quickly inside, while outside, the square becomes a shortcut for workers, students, and the homeless, who huddle in corners away from the wind.

Beneath it, the underground city offers refuge but not warmth: tiled corridors buzzing with fluorescent light, stairwells smelling faintly of mildew, and escalators that clatter endlessly. The hum of the metro rises through the walls, a constant reminder that the city’s pulse flows just below the polished veneer.

 The Place des Arts is caught between ambition and decay, spectacle and emptiness—a cultural stage set where the performance inside glitters, but the concrete plazas outside whisper of urban loneliness, as though the institution itself were performing against the city’s own entropy.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Quartier des Spectacles", "Underground City"],
		"characters": []
	},

# ---------- Underground City Zone ----------
	"Underground City": {
		"zone_name": "Underground City",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The tunnels around Place des Arts are some of the most unsettling stretches of the Underground City—long, echoing corridors where modernist ambition has already begun to sour into neglect. The walls are clad in pale tiles, once gleaming, now dulled and cracked, their grout lines stained with grime. The lighting is fluorescent and uneven, tubes buzzing overhead, some blinking in a pulse that seems almost intentional, like a signal only the walls can read.
The air here is damp, carrying the smell of concrete dust and old rainwater that seeps down from the plazas above. When the fountains outside go still in winter, their silence seems to bleed down through the walls, adding to the hollow quiet of the corridors. Even during the day, foot traffic thins quickly once you leave the main arteries. The further you walk, the more the space feels like a set left behind after the performance, hallways echoing with the ghosts of audiences who never returned.
At night, when the shops close and the entrances are barred, the tunnels slip into a kind of suspended dream. The echoes become sharper, the corners darker. You catch glimpses in the mirrored panels of shuttered boutiques—shapes that seem to hesitate when you move, lagging just slightly behind your reflection. The stairwells leading up into Place des Arts itself are wide and brutalist, their concrete stained with damp patches, their handrails cold to the touch. Some claim you can hear faint music drifting down them when the halls above are empty—notes of piano or strings, dissonant and distant, as though rehearsed by unseen hands.
This segment of the Underground City feels like a liminal stage beneath a stage—Place des Arts above dazzling in light and performance, while below, its shadow broods in concrete silence, whispering of rehearsals no one living should attend.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Place des Arts", "Complexe Desjardins", "Place des Arts Metro", "Cirque Des Monstres", "Old Montreal Underground (Tunnels)"],
		"characters": []
	},

# ---------- Cirque Des Monstres Zone ----------
	"Cirque Des Monstres": {
		"zone_name": "Cirque Des Monstres",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Music, bright and cacophonic whispers through old industrial access tunnels. It calls people onward toward flickering lights and shadows cast by firelight, not electricity; It's not quite an Old World sound, but one that never existed - a dream of an idea of a time and a place, apart from the 'now' - a place of possibility, wonder... and a distinct edge of danger. You're not safe here... but you are free.

Just behind the bustle of the main tunnels of the Underground City lies the current home of the Cirque Des Monstres. It's an indie production, often popping up whenever and wherever it can in abandoned warehouses, empty rave venues, and fairgrounds around the Montreal metro area. It's found by word of mouth, or by the advertising posters plastered in the windows of other alternative cafe's, shops, clubs and music stores.

The circus has the air of a budget-friendly Cirque Du Soleil - populated by the rejects of the more glittering, mainstream performing circuit. The performers at the Cirque Des Monstres are a little edgier, a little stranger, and the acts are more avante-garde. Alongside those provoking awe and wonder are acts bound to horrify and dismay, balancing carefully between a waking dream and a nightmare.

Various acrobats, magicians, jugglers and more are advertised, and one of the headlining acts is someone called 'The Dancing Crow'.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Underground City"],
		"characters": []
	},

# ---------- Complexe Desjardins Zone ----------
	"Complexe Desjardins": {
		"zone_name": "Complexe Desjardins",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Complexe Desjardins stands as both a monument to modern commerce and a strange, cavernous crossroads in the center of downtown Montreal. Its three towers loom above, but what most people remember is the interior—a massive atrium where natural light pours down through glass skylights, diffused across tiers of concrete balconies and wide walkways.


By day, the place hums with the rhythm of offices, shoppers, and travelers. The ground level buzzes with food courts and scattered fountains, their tiled basins rimmed with damp mineral stains. Escalators glide constantly, carrying people between levels like blood through veins, while the echo of footsteps and chatter merges into a constant hum. The mall-like corridors radiating outward are lined with shops—some polished, others already showing signs of fatigue: flickering neon, outdated signage, displays that seem frozen in time.


Yet even in the daylight bustle, there is a coldness to the scale.The concrete is pale but impersonal, softened only slightly by plants and banners that never quite disguise the weight of the architecture. Sound doesn’t just echo here—it hangs, overlapping in a way that makes voices seem both close and far at once.
At night, when the crowds thin, the atmosphere shifts. The atrium’s openness becomes cavernous, almost void-like, and the fountains gurgle too loudly in the emptiness. Fluorescent lights wash everything in a sterile glow that makes the tiled floors look yellowed and worn. The connecting tunnels to the Underground City stretch away from its lower levels, yawning into corridors where foot traffic dwindles to nothing. Down there, the hum of escalators and ventilation fans seems amplified, filling the silence like mechanical breathing.It’s a space of convergence, but also of uncanny dislocation, a mall and a machine at once, as if the city had hollowed out a vast chamber just to see what would gather inside.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Rue Sainte-Catherine", "Underground City"],
		"characters": []
	},


# ---------- A lonely, barren room Zone ----------
	"A lonely, barren room": {
		"zone_name": "A lonely, barren room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This small room in the infrastructure of the city's underground has somehow been untouched by recent developments, perhaps forgotten by city planners, or overlooked as not worth the time and money. Someone, though, has dragged in some bare essentials over time, making the place technically livable. A small table repurposed as an uncomfortable bed, and a smalled bench to use as a wobbly table for the occasional times when it occupant has enough possessions in the moment to put something somewhere.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Complexe Desjardins", "Underground City"],
		"characters": [],
		"secret_entry_passwords": ["Sewerlubri"],
		"accessible_from_zones": ["Complexe Desjardins"]
	},

# ---------- Rue Sainte-Catherine Zone ----------
	"Rue Sainte-Catherine": {
		"zone_name": "Rue Sainte-Catherine",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Rue Sainte-Catherine is the restless artery of downtown Montreal—long, crowded, and contradictory. It’s where neon and grit live side by side, a place of shopping bags and cigarette smoke, of laughter, traffic, and the hum of something slightly off beneath it all. By day, the street is alive with students from Concordia and UQAM, office workers spilling out for lunch, and shoppers weaving between department stores, boutiques, and arcades.By night, Sainte-Catherine changes. The neon signs flare brighter, casting pinks and greens across wet pavement, while the shadows lengthen in the alleys that break away from the main drag.
The pavement is cracked, litter gathers in corners, and the homeless take shelter in doorways, their presence a stark reminder of the city’s fractures. Steam rises from the grates in winter, blurring the lights into ghostly halos. The metro entrances yawn at intervals, stairwells leading down into fluorescent tunnels, as though the street itself has a hidden labyrinth beneath it.

 Rue Sainte-Catherine is neither clean nor safe, but it is alive—electric with movement, layered in contradictions. Glamorous and decayed, commercial and carnal, it is the city’s stage and its shadow at once. In the quieter hours, the street feels endless, haunted by its own neon reflections.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Complexe Desjardins","Griffontown", "Downtown Montreal"],
		"characters": []
	},




############### Sans Nom Haven ###################

"Punkhouse - Sans Nom": {
	"zone_name": "PunkhouseSansNom",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "A tired three-story house at the end of an alley, once carved into cheap apartments for factory workers. The landlord disappeared years ago, so no one’s paid rent in forever. Windows are cracked and patched with plywood, graffiti layers every surface - anti-police slogans, anarchist scrawl, Sabbat sigils hidden in punk tags. The front door is barricaded with scavenged car doors and rebar.\n\nThe front stoop doubles as a gathering spot for wayward souls and night strays. Rusted bikes and stolen shopping carts litter the yard. A burned-out car frame sits permanently on the curb, used as a bonfire pit when the pack hosts ragers. Flyers for long-dead shows and causes peel from telephone poles. The few remaining neighbors know better than to complain. The sounds of police sirens do not reach this place.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Downtown Montreal", "Punkhouse - Sans Nom : Main"],
	"characters": [],
	"secret_entry_passwords": ["sansnom"],
	"accessible_from_zones": ["Downtown Montreal"]
},

"Punkhouse - Sans Nom : Main": {
	"zone_name": "Punkhouse: Main",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "The walls of the main room are stripped to bare brick and spray-painted with slogans in a bad French-English mix: “PAS DE DIEU, PAS DE MAÎTRES, JUSTE LE SANG.” Old couches, some missing legs, are arranged haphazardly in a circle around a cracked table stained with candle wax and what might be blood.\n\nA door leading to what was once a kitchen is marked with “PAS FUMER ICI SI TU VEUX VIVRE FUCKO”.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Punkhouse - Sans Nom", "Punkhouse - Sans Nom : Lab", "Punkhouse - Sans Nom : Depths"],
	"characters": []
},

"Punkhouse - Sans Nom : Lab": {
	"zone_name": "Punkhouse: Lab",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "It used to be a kitchen. The fridge hums sometimes but doesn’t reliably keep cold. It seems consigned to its new duties, packed with reagent bottles, jars of powder, and unlabeled vials of cloudy liquid instead of food. The oven door is permanently open, its racks turned into makeshift drying trays for chemicals and herbs.\n\nShelves that once held dishes now bow under mason jars stuffed with dubious compounds - some crystalline, some sludgy, a few clearly organic in origin. There’s a box of pharmacy pill bottles, their labels half-peeled, and several small notebooks smeared with coffee, blood, and chemical burns.\n\nAgainst one wall is the “bomb bench”: an old door laid across sawhorses, littered with wires, nails, glass bottles, and duct tape. A cracked Polaroid camera hangs above it, used to snap progress shots in case the artisan blows himself up and someone needs to figure out what went wrong.\n\nEvery surface smells of acetone, bleach, and vinegar. The sink is perpetually clogged with unidentifiable sludge, and the tap water runs rusty. The floor is sticky with old spills. The boombox in the corner refuses to turn off, perpetually blasting music into the air—drowning out hissing burners and the faint chemical pop of reactions gone sideways. A chair for company sits in the corner.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Punkhouse - Sans Nom : Main"],
	"characters": []
},

"Punkhouse - Sans Nom : Depths": {
	"zone_name": "Punkhouse: Depths",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "The depths of the house stretch beneath the cracked foundation like a half-forgotten warren. A steep stairwell drops into darkness where the air is always damp and tinged with mildew, old ash, and chemical rot. Down here, the space is carved into makeshift bedrooms, each more like a shelter than a home.\n\nWalls are built from scavenged plywood, dented lockers, hollow doors pulled from alleys. Curtains made from bed sheets, flags, or tarps hang where walls couldn’t be made solid. Inside each space, the “beds” range from stained mattresses on palettes to piles of blankets on the concrete floor. Stray furniture—a broken dresser, a desk rescued from a curb, a steel gurney—has been dragged down and repurposed.\n\nThe hallway that links them is narrow, illuminated by Christmas lights stapled overhead, half of them flickering, the other half burnt out. Pipes run along the ceiling, dripping steadily into rusting pans and plastic tubs, the constant tap-tap-tap echoing like a clock that never stops.\n\nAt the far end, past the bedrooms, the basement opens into a communal chamber and ritual space. It is a lounge, host to a dented steel table, ringed with mismatched chairs and crates.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Punkhouse - Sans Nom : Main"],
	"characters": []
},

###################################################


"McGill – Downtown Campus": {
	"zone_name": "McGillDowntownCampus",
	"default_viewpoint": "main",
	"category":"montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "McGill’s downtown campus sits like a question posed to the city around it. Surrounded by churches and the heavy breath of history, it doesn’t kneel or rebel. It negotiates. Limestone and copper, brick and glass, each building speaking in its own strange cadence. The place feels thoughtful in the way of someone watching you from a window you hadn’t noticed. You walk its paths and feel the ground has been considered. Not sacred. Not modern. Just aware. The result isn’t harmony. It’s something colder, more honest. A new ancient rising at the foot of the mountain, knowing exactly what it is.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Peel–Pine Stairwell", "Downtown Montreal", "Plateau Mont Royal"],
	"characters": []
},




"Peel–Pine Stairwell": {
	"zone_name": "PeelPineStairwell",
	"default_viewpoint": "main",
	"category":"montreal_high_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "At the corner of Peel and Pine, the stairs begin without ceremony, slipping up into the trees with a tilt that feels too steep, too narrow, like they were never meant for comfort. The concrete is cracked and damp in places, bordered by rusted railings and patches of green that crowd close as if trying to hide what lies ahead. There’s no clear reason for the unease that settles in as you climb, only a slow tightening in the chest, a quiet certainty that something is watching from beyond the bend. The city noise fades too quickly, and the path bends out of sight as though leading not into a park, but toward something waiting just out of reach.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Mount Royal – Lower Stair", "McGill – Downtown Campus"],
	"characters": []
},

"Professor Usaz's Home": {
	"zone_name": "Professor Usaz's Home",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "The room feels lived in and quietly scholarly. Shelves line the walls, each one heavy with old books and rolled parchments, their covers worn and their pages yellowed with time. A single armchair rests near a small fireplace, its cushions shaped by years of use. A solid oak desk stands nearby, its surface scattered with papers, notes, and an ink-stained blotter. Though the home is simple and unpretentious, it carries a sense of warmth and familiarity. The faint scent of paper and pipe smoke lingers in the air, giving the place a feeling of calm and quiet focus.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Peel-Pine Stairwell"],
	"characters": [],
	"secret_entry_passwords": ["Faulkner"],
	"accessible_from_zones": ["Peel-Pine Stairwell"]
},




"Mount Royal – Lower Stair": {
	"zone_name": "MountRoyalLowerStair",
	"default_viewpoint": "main",
	"category":"Forest001",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "At the foot of Mount Royal, the stairs rise in silence. The little lights of the night do not follow you here. Trees press in close, their limbs twisted like old thoughts. The stone is wet and uneven, each step inviting and indifferent. A rusted rail guides the way, but it feels more like a boundary than a help. Below, water slips into a tunnel with no name. Above, the forest thickens. You climb not because you want to, but because something in you already has.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Mount Royal – Upper Stair" ,"Peel–Pine Stairwell"],
	"characters": []
},

"Mount Royal – Upper Stair": {
	"zone_name": "MountRoyalUpperStair",
	"default_viewpoint": "main",
	"category":"Forest001",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The stairs vanish upward into a black canopy, slick with rain and the smell of soil. Behind you, the city flickers with neon, engines, and the hum of the living, but here it’s all gone. You are still in Montreal, technically. But that no longer matters. The noise does not reach this far, not past the first few steps. Only the cold does. The trees lean in, too close, like they have been waiting for someone to notice. The railing is cold iron and the path ahead bends just enough to hide whatever waits at the top. You keep climbing anyway. Something has already decided you will.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Mount Royal – Grand Staircase", "Mount Royal – Lower Stair"],
	"characters": []
},

"Mount Royal – Grand Staircase": {
	"zone_name": "MountRoyalGrandStaircase",
	"default_viewpoint": "main",
	"category":"Forest001",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The Grand Staircase cuts up the mountain with a kind of civic pride that feels forced, its symmetry too clean against the wild slope it tries to tame. The stone is polished where thousands have passed, but the air stays heavy and damp, filled with the scent of root rot and iron. You can see the skyline behind you if you turn, but it looks small now, unreal, like a stage set left lit after the actors have gone home. The higher you climb, the more the structure feels like a monument to something unspoken. Not celebration. Not grief. Just presence. Quiet and watching.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Mount Royal – Trail Split" ,"Mount Royal – Upper Stair"],
	"characters": []
},

"Mount Royal – Trail Split": {
	"zone_name": "MountRoyalTrailSplit",
	"default_viewpoint": "main",
	"category":"Forest001",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "At the top of the Grand Staircase, the world hesitates. The trees thicken and the sky disappears, leaving only the soft dark of the path and the way it splits without reason. No signs, no lights, just the hum of stillness pressed close. The forest is deeper here, more certain of itself. You are meant to choose, but the choice feels wrong, like stepping into a sentence you did not begin. Behind you, the stone steps end cleanly. Ahead, the trail folds into shadow. One direction pulls, the other waits. Neither welcomes.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Mount Royal – The Cross", "Mount Royal - Overlook", "Mount Royal – Grand Staircase"],
	"characters": []
},

"Mount Royal - Overlook": {
	"zone_name": "MontRoyalOverlook",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The trees pull back here, not like an invitation but a hesitation, as if the forest itself is afraid of the view. The path that leads in is narrow and disloyal, half-swallowed by roots and disuse, never marked on any official map. At its end, the city waits. Distant. Red-lit. Alive with motion it doesn’t understand. Towers rise from the dark like teeth. Streets glow faintly, pulsing with the tired blood of midnight traffic. There is no rail. Only the wind, and the drop, and the sense that you were never supposed to find this place. But you did. And now it sees you too.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Mount Royal – Trail Split"],
	"characters": []
},

"Mount Royal – The Cross": {
	"zone_name": "MountRoyalTheCross",
	"default_viewpoint": "main",
	"category":"Forest001",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "And then, through the trees, it appears. The Cross. Towering and radiant, humming with unnatural color that stains the ground in shades of violet and blood. It rises from the earth like something unearthed rather than built, too large and too precise, as if it had been waiting. The fence around it offers no protection, only distance. Everything here feels paused, as though even the forest is holding its breath. You do not speak. You do not move quickly. The city is far below now and irrelevant. This is not a landmark. It is a revelation. And it sees you.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Mount Royal – Trail Split"],
	"characters": []
},






"Westmount": {
	"zone_name": "Westmount",
	"default_viewpoint": "core",
	"category":"montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"core": {
			"image_path": "",

			"description": "Westmount rests heavy on the hillside, wrapped in old money and quiet pride, a pocket of privilege pretending the city beyond the trees does not exist.\n
Stone manors and heavy greystones crouch behind iron fences, their windows casting faint glows onto manicured streets built to last longer than memory.\n
Downtown flickers in the distance, a smear of broken color across the horizon, bleeding through the night like a wound no one here dares to name.\n
They fret over the noise, the lights, the restless fever of the streets below.\n
But it is not the city that watches them.\n
It is Mount Royal, crouched and breathing, patient as stone, waiting for the moment when the earth remembers what was built on its back.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Downtown Montreal", "Côte-des-Neiges", "Notre-Dame-de-Grâce", "Sud-Ouest"],
	"characters": []
},

	"Notre-Dame-de-Grâce": {
		"zone_name": "NDG",
		"default_viewpoint": "Main",
		"category":"montreal_high_outside",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "NDG stretches wide and low across the hillside, a maze of battered brick and narrow streets that never quite forget the weight of the city pressing down.\n
	The mood here is heavy but honest, worn into the sidewalks and stitched into the tired faces that pass without hurry.\n
	It is not a place built for dreams but for endurance, for the slow unremarkable victories of another day survived.\n
	Far off downtown burns in restless colors, louder and faster than anything here.\n
	The mountain leans closer too, its shadow a constant presence, but NDG does not flinch.\n
	It moves at its own rhythm, slow, heavy, stubborn enough to outlast the noise.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Côte-des-Neiges", "Côte Saint-Luc", "Westmount", "Montreal West", "Sud-Ouest", "Westmount"],
		"characters": []
	},

"Côte-des-Neiges": {
	"zone_name": "CoteDesNeiges",
	"default_viewpoint": "Main",
	"category": "montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "Côte-des-Neiges doesn’t shine. It leans. Into the mountain, into itself, into the weight of too many lives stacked too quickly.\nLanguages blur on the wind. The street signs offer translation, not clarity. Groceries hum with incense and cheap fluorescent light. The buildings don’t rise, they huddle.\nSomewhere beneath the concrete, the mountain breathes. Not loudly. Just enough to remind you it’s older than your prayers. Older than any city that thought it could claim it.\nChildren here grow up translating their parents’ fears. The church bells still ring, but softer now, as if apologizing. And the paths into the woods are still there, even when no one talks about them.\nCôte-des-Neiges remembers what the city forgets. And it waits. Quiet. Watching.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Décarie Sector", "Notre-Dame-de-Grâce", "Westmount", "Saint-Laurent", "Côte Saint-Luc", "Ahuntsic-Cartierville", "Parc-Extension"],
	"characters": []
},



"Montreal West": {
	"zone_name": "MontrealWest",
	"default_viewpoint": "main",
	"category":"montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Montreal West is not a place but a refusal, a quiet held so tightly it hums, streets arranged like old arguments, Protestant grids imposed on land that still remembers wolves. The lamps are too white, the air too clean, the houses too still, like someone designed the neighborhood from memory and got the texture wrong. Nothing bleeds here. Not openly. The sidewalks are edged with hedge-trimmed diplomacy, and the train tracks run like old surgical scars beneath it all. Somewhere between the golf course and the commuter rail, God was put in a filing cabinet and left there to yellow.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Lachine Canal", "Côte-des-Neiges", "Notre-Dame-de-Grâce", "Lachine", "LaSalle"],
	"characters": []
},


"Lachine": {
	"zone_name": "MontrealLachine",
	"default_viewpoint": "main",
	"category":"montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Lachine is where the city began lying to itself, a mouth carved into the island to chase trade and ended up swallowing time instead. The canal, once the lifeblood of empire and ambition, still cuts through the borough like a prophecy written in stone and silt. Grain towers lean like tired saints, rail lines vanish into the weeds, and old brick warehouses sleep beside the water, dreaming of steam and soot. This is Montreal before neon, before glass, a place where the bones of industry still press up through the pavement, reminding everything modern that it is temporary.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Lachine Catholic Cemetery", "Boulevard Saint-Joseph", "Lachine Canal", "Montreal West", "Côte Saint-Luc", "Dorval", "Saint-Laurent", "LaSalle"],
	"characters": []
},



# ---------- Lachine Canal Zone ----------
	"Lachine Canal": {
		"zone_name": "Lachine Canal",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Although the Lachine Canal once served as the gateway between the Great Lakes and the Rest of the World, it has fallen into disuse since the Saint Lawrence Seaway opened in 1959.

Today, the canal is dotted with abandoned and crumbling factories and docks. The structures are used by homeless and runaways who seek shelter from the elements, their parents or even their pasts. 

The Sabbat usually raid these factories when *stocking up* for blood feasts.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Singer Sewing Machine Factory", "Textiles du Petomane", "LaSalle", "Sud-Ouest", "Montreal West", "Old Montreal", "Pointe-du-Moulin"],
		"characters": []
	},

# ---------- Singer Sewing Machine Factory Zone ----------
	"Singer Sewing Machine Factory": {
		"zone_name": "Singer Sewing Machine Factory",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The old Singer Sewing Machine Factory was one of the last businesses to die on the Canal. Now it is a last resort refuge for the desperate, and a playground for the inhumane. If it wasn't for the stench of piss and putrefaction, the waterside scene of an old factory would seem romantic. But the moment this area quit making people money, people stopped caring. 

The windows are almost all broken from years of rock throwing. Some of them house jagged shards still in the frame, and covered in dried blood. There seems to be no lack of an open point of entry, or garbage surrounding the building.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Singer Factory Floor", "Lachine Canal"],
		"characters": []
	},

# ---------- Singer Factory Floor Zone ----------
	"Singer Factory Floor": {
		"zone_name": "Singer Factory Floor",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The work floor was once an assembly line, cranking out sewing machines to N. America s housewives, and tailors. Now it s an empty shell full of litter, old oil drums used as fire pits, and crude graffiti made up of spray paint, feces and blood. The smells of piss and putrefaction are strong here. 

 Fuck Trudeau!!  is spray painted on the floor almost immediately after entering. 

There is a skittering across the concrete. It should just be rats, right?",
				"sound_path": ""
			},
		},
		"connected_zones": ["Singer Sewing Machine Factory"],
		"characters": []
	},

# ---------- Textiles du Petomane Zone ----------
	"Textiles du Petomane": {
		"zone_name": "Textiles du Petomane",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The Wm. J. le Petomane Textile Factory should be condemned. It probably would be if anyone gave a shit. A storm will come through here one day, and it will collapse this building on whoever is squatting here at the time.

The smell of the polluted canal is strong here. The sounds of its waters rush against the nearby banks. They draw eyes to the water where they spot the bow of a half-sunken tug boat. No light seems to be coming from within.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Lachine Canal", "Petomane Factory Floor"],
		"characters": []
	},

# ---------- Petomane Factory Floor Zone ----------
	"Petomane Factory Floor": {
		"zone_name": "Petomane Factory Floor",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The 2nd floor of the Factory is starting to come down onto the 1st. The place stinks of vermin waste. What you hope are rats skitter unseen across both floors. 

Outside of the garbage and filth people have brought in over the years, there isn t much here. This place was cleaned out when they closed down leaving the rotten wood and rusting frame of this one thriving business. ",
				"sound_path": ""
			},
		},
		"connected_zones": ["Textiles du Petomane"],
		"characters": []
	},

"Lachine Catholic Cemetery": {
	"zone_name": "MontrealLachineCatholicCemetery",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The Lachine Catholic Cemetery does not mourn; it settles into itself with the quiet certainty of stone and soil. Headstones lean like tired men at mass, their names worn down by weather and time. The wrought-iron gate hangs open just enough to suggest invitation, but the gravel path beyond feels more like a threshold than a welcome. Pine needles collect in the corners of forgotten plots, and the wind moves like something trying not to be noticed. This place remembers a different town, one built on rosaries and railway schedules, when the parish still believed eternity could be measured in parish records and cold marble. Now it is a museum of grief no one visits, a hollow quiet where the dead are kept orderly and the living know better than to linger.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Within Lachine Catholic Cemetery", "Lachine"],
	"characters": []
},

"Within Lachine Catholic Cemetery": {
	"zone_name": "MontrealLachineCatholicCemeteryInterior",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "It sure is spooky here.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Lachine Catholic Cemetery"],
	"characters": []
},

"Boulevard Saint-Joseph": {
	"zone_name": "MontrealBoulevardSaintJoseph",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "This is the boulevard where Lachine puts on its good shirt. The one without the holes, ironed flat and sprayed with cheap cologne. Boulevard Saint-Joseph is clean in the way morgues are clean. Tiled, scrubbed, and humming under fluorescent lights. Tourists drift past flower beds arranged by forgotten committees. There are plaques, benches, municipal promises. But nothing grows here except suspicion. Behind the smiling cafés, families sleep three to a room. Behind the heritage signs, drywall peels in long, curling strips like a confession.\n\nThe canal once spat out visitors here, so the city built a stage. They swept the concrete. They put lanterns in the trees. No one talks about the break-ins, the overdoses, the way the wind seems to carry sirens from streets you are not supposed to see. But they are there, stitched just behind the brick. You can feel them if you stand still long enough. The hum of rot beneath civic pride. The long ache of a place pretending it was never poor.\n\nThe boulevard smiles for the photo. Its eyes are elsewhere.",
			"sound_path": ""

		}
	},
	"connected_zones": ["El Meson Front", "Lachine"],
	"characters": []
},


"El Meson Front": {
	"zone_name": "MontrealElMesonFront",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The front of El Meson is holding itself together with salsa and spite. The stucco is peeling, the sign is half-lit, and the patio furniture has clearly seen some things, but the smell ( charred meat, lime, grease, smoke ) is the kind of perfume that makes you forgive architecture. A busted speaker inside plays the same ranchera it did yesterday and the day before that, as if time here isn’t linear but circular and full of laughter. Stray cats drift through like ghosts of old customers, and the pigeons look at you like they know your order. Something about this place insists it is still alive. Not just open. Alive.",
			"sound_path": ""

		}
	},
	"connected_zones": ["El Meson Inside", "Boulevard Saint-Joseph"],
	"characters": []
},

"El Meson Inside": {
	"zone_name": "MontrealElMesonInside",
	"default_viewpoint": "main",
	"category": "Restaurant001",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Inside El Meson, it's always just past midnight and nobody’s ready to go home. The air buzzes with music from a busted jukebox that somehow always hits the right song, something warm and nostalgic with too much reverb. Laughter bounces off the tiled walls, mixing with the sizzle from the kitchen and the clatter of plates that have been refilled twice already. A glowing red crucifix watches from above the bar like it’s in on the joke. The chandeliers rattle with every cheer, and the Virgin portraits look amused under the neon light. Tables are packed with regulars and strangers alike, passing tacos and ghost stories in the same breath. The floor is sticky in spots and the tequila is cheaper if you don't ask questions. And no matter how late you stumble in, the cook’s cousin or brother or maybe just some guy who lives upstairs always greets you with the same booming “¡Hola señor!” like you’ve been expected all along. This is a place that doesn’t close. It just pauses for breath.",
			"sound_path": ""

		}
	},
	"connected_zones": ["El Meson Front"],
	"characters": []
},


	"Montréal-Nord": {
		"zone_name": "MontrealNord",
		"default_viewpoint": "main",
		"category":"montreal_high_outside",
		"is_neighborhood": true,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The pavement is stained before you arrive. Oil, piss, something darker. Montréal-Nord doesn’t hide it. It presents the violence like a menu.\n
	A man shouts from a balcony. Another one doesn’t respond. Minutes later, there’s glass on the ground and a woman screaming into a disconnected phone.\n
	Neon buzzes above a dépanneur with bulletproof glass. Inside, the cashier counts pills into a napkin. No one speaks. You hear the hum of a fridge and the click of a safety switch.\n
	Kids play soccer near a taped-off alley. One of them kicks too hard and the ball rolls into blood. They laugh and keep going.\n
	In the stairwell, someone is crying. It sounds like they’ve been doing it for days.\n
	Everything smells like metal and snowmelt. The lights twitch. The shadows twitch back. You walk faster, but the city doesn’t let go. It clamps around you like a hand.\n
	Nothing breathes here. It seethes.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Boulevard Saint-Michel : Montréal-Nord", "Boulevard Industriel", "Saint-Michel", "Saint Leonard", "Ahuntsic-Cartierville", "Rivière-des-Prairies"],
		"characters": []
	},



# ---------- Boulevard Saint-Michel Zone ----------
	"Boulevard Saint-Michel : Montréal-Nord": {
		"zone_name": "Boulevard Saint-Michel",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": " The Boulevard Saint-Michel - where the working people press together into a too short stretch of bars, restaurants and clubs, hoping to drown the hard day's work into a glass (or five).  Here, fights and disappearances are just a matter of time - and  few are missed, in the constant flux of migrants struggling to make a life for themselves. Drug deals go down in back alleys and prostitutes loiter on the sidewalks.

Foreign faces cluster together in hopes of making a community in an unfamiliar and hostile place. Clinging to those small threads of similarity to ground them in the isolating pulse of a city all too keen to take, until there was nothing more to give. Here they drown their sorrows, dance away worries, and make all the poor decisions that will haunt them at work the next day, when the hangover comes calling.",
				"sound_path": ""
			},
   "Alleyways": {
				"image_path": "",

				"description": "Just beyond the thrum of Boulevard Saint-Michel, where neon signs burn and music spills from open doorways, the alleyways begin like hidden fractures in the city's body. Step a few paces off the boulevard and the sound of revelry muffles, collapsing into echoes, the bass of nightclub speakers reduced to a dull vibration that seems to pulse through the stone.

The alleys are narrow, hemmed in by the back walls of bars and cafés, their bricks sweat-stained and tagged with graffiti layered over decades. Trash bins overflow, their metal sides dented and streaked with something sticky, sweet, and sour in the air. Light comes in uneven patches from lamps bolted high on walls, most of them flickering or haloed with grime. It feels as though the alleyways are waiting-narrow channels of brick and shadow, pressing in close, swallowing whatever wanders too far from the lights of Saint-Michel.",
				"sound_path": ""
			}
		},
		"connected_zones": ["Couche-Tard : Boulevard Saint-Michel", "Montréal-Nord"],
		"characters": []
	},
# ---------- Couche-Tard Zone ----------
	"Couche-Tard : Boulevard Saint-Michel": {
		"zone_name": "Couche-TardBoulevard Saint-Michel",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A neon 'open' sign blazes from the window all hours of the night. The fluorescent lights flicker overhead, illuminating the cigarettes and lotto cards on sale behind the counter. It is what it is, and makes no pretension otherwise. In that way, it is comforting.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Boulevard Saint-Michel : Montréal-Nord"],
		"characters": []
	},



	"Saint-Michel": {
		"zone_name": "SaintMichel",
		"default_viewpoint": "main",
		"category":"montreal_high_outside",
		"is_neighborhood": true,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The ground here remembers being torn open.\n
	Saint-Michel sprawls over a quarry full of water, junk, and rot. The factories cough smoke or sit hollow. The air sticks. Everything smells like rust and burnt wires.\n
	Triplexes lean close. The alleys stay wet. Furniture lives on balconies year-round. Oil stains run down the stairs. Nothing moves fast. Fights start slow, then don’t stop.\n
	The metro buzzes like a nerve. Sirens pass without slowing. Fires start and no one asks why.\n
	Saint-Michel doesn’t wait. It watches. It presses. It wants to see what breaks first. It hopes so dearly that it'll be itself.",
				"sound_path": ""

			}
			
		},
		"connected_zones": ["Saint-Michel Metro – Exterior", "Avenue Charland", "Montréal-Nord", "Saint Leonard", "Ahuntsic-Cartierville", "Rosemont", "La Petite-Patrie", "Villeray"],
		"characters": []
	},

"Avenue Charland": {
	"zone_name": "Avenue Charland",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Avenue Charland runs tight between its rows of worn brick, where neon leaks down in streaks and the fog bends the light into crooked halos. Signs buzz overhead, painting the wet pavement in sickly color. Puddles stretch the reflections into claws, each lamp and bar sign warped until it feels more like a wound than a glow. The street itself feels narrow not from its width, but from the weight pressing in on both sides.\n\nHere, doorways lean forward as if listening. Graffiti coils into symbols no one remembers writing. The air tastes of metal, damp stone, and smoke, heavy enough that every breath feels stolen. Avenue Charland is not silent, but its voice is buried under the static of its own lights, muttering just low enough that you cannot decide if you should leave or listen.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Avenue Charland : Hole in One", "Saint-Michel"],
	"characters": []
},

"Avenue Charland : Hole in One": {
	"zone_name": "Avenue Charland: Hole in One",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "The Hole in One in Saint-Michel sits like a bruise on the block, equal parts neon lure and concrete bunker. The exterior is a low, squat building with a retrofitted façade that pretends at glamour. Cheap neon tubing shaped into a martini glass glows above the front doors, the word HOLE blinking more often than it stays lit, while the “IN ONE” buzzes faintly, half-fried from years of neglect. The windows are blacked out, painted or tinted so no one on the street can peek in, and the entrance is set into a recessed alcove framed by flickering red lights. A hand-painted sign advertises nightly shows and “VIP Rooms,” letters peeling under the glow.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Avenue Charland", "Hole in One"],
	"characters": []
},

"Hole in One": {
	"zone_name": "Hole in One",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "The main floor of the club sprawls out in a wide rectangle, anchored by a long, sticky bar running along the left-hand wall. Behind it, bottles of liquor, cheap and mid-shelf mostly, are lined up in front of a huge mirror clouded with age. A tired looking barmaid in fishnets and a leather miniskirt tends to the regulars, her tired smile rehearsed, but her eyes sharp.\n\nA couple of security cameras peek from above the shelves, their feeds piped somewhere back to the manager’s office, watching every angle.\n\nAround the stage, rows of small round tables press close together, sticky rings of old drinks staining their surfaces. Patrons sit slouched in their chairs, throwing bills or staring with glassy eyes. Farther back, booths line the walls in shadow, offering more privacy for deals, whispered conversations, or whatever else money can buy here.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Avenue Charland : Hole in One"],
	"characters": []
},

"Hole in One: Blake's Office": {
	"zone_name": "Hole in One: Blake's Office",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "Blake’s office is everything you’d expect from a seedy strip club manager who thinks he’s living the high life. The smell hits first: a mix of stale cigar smoke, cheap cologne, and the faint chemical tang of whatever drug residue lingers in the carpet fibers.\n\nThe centerpiece is a massive waterbed, its black vinyl sheets tacky with age, rimmed with brass piping, and surrounded by mirrors bolted to the walls and ceiling, so every angle of excess can be seen twice over. The mattress sloshes with any movement, sending lazy waves across the surface. A red silk throw lies crumpled at the foot, like an afterthought of decadence.\n\nAlong the right-hand wall sits a couch in gaudy cheetah print, threadbare at the arms but still loud enough to draw the eye. It’s flanked by two glass topped end tables, stacked with ashtrays, pill bottles, and a couple of empty bottles of liquor. The floor beneath is littered with cigarette butts, old magazines, and the occasional wrapper from fast food left to rot.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Hole in One"],
	"characters": [],
	"secret_entry_passwords": ["Blake"],
	"accessible_from_zones": ["Hole in One"]
},


"Saint Leonard": {
	"zone_name": "Saint Leonard",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Saint Leonard pretends at suburbia, but the asphalt remembers the farms. Rows of bungalows sit where grapevines once stretched, and the smell of soil still clings to basements and garages. The streets are wide, the houses close, and everyone knows everyone else’s curtains. It feels safe until the sodium lamps flicker and the alleys fill with steam from the sewer grates. The kids who grew up here wear leather now, leaning against parked cars outside strip malls, smoking with the same hands their fathers used to prune vines. Old men play cards in cafés that never close, their voices hoarse with dialect and suspicion. The night is calm but restless, lit in slices of red and green from corner bars.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Montréal-Nord", "Saint-Michel", "Anjou", "Rosemont"],
	"characters": []
},


# ---------- Lost Ladle's Kitchen Zone ----------
	"Lost Ladle's Kitchen": {
		"zone_name": "Lost Ladle's Kitchen",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A soup kitchen owned and ran by a woman named *Lady* Maggie Apatos. The shop runs late into the night, it's soft neon lights offering respite for the city's lost.  ",
				"sound_path": ""
			},
		},
		"connected_zones": ["Saint Leonard"],
		"characters": [],
		"secret_entry_passwords": ["Soup"],
		"accessible_from_zones": ["Saint Leonard"]
	},




"Ahuntsic-Cartierville": {
	"zone_name": "Ahuntsic-Cartierville",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Ahuntsic-Cartierville moves like the old north of the island forgot how to change. The factories near Chabanel still breathe behind thick doors, while the river slides past warehouses and brick duplexes gone soft at the edges. Families live above dépanneurs where the bell barely rings, and the parks near Sault-au-Récollet hold on to rituals no one admits to practicing. Hôpital Fleury watches from its corner like a bureaucrat in a white coat, always lit, never blinking. Planes pass overhead, low and constant, but never seem to land. This isn’t the end of the city. It’s where the static settles.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Fleury Hospital: Exterior", "Saint-Michel", "Montréal-Nord", "Parc-Extension", "Villeray", "Saint-Laurent"],
	"characters": []
},

"Fleury Hospital: Exterior": {
	"zone_name": "Fleury Hospital: Exterior",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Fleury Hospital is where people go to die. Towering over the district, it looms like a magnifying glass over an anthill, sterilizing the otherwise dingy surroundings. This is not a place of healing, but of waiting for the inevitable to come to a population most would rather ignore.

The smell of bleach and coffee assaults the nostrils when entering. The presence of death makes this place seem older than it really is. Everyone seems so solem, everything so unclean. A semi-circlular desk and a hanging sign above it reading, ACCUEIL welcomes guests with a red courtesy phone a few meters after walking in.",
			"sound_path": "[ambulance siren, city sounds]"
		},
		"Emergency Entry": {
			"image_path": "",

			"description": "The emergency entry is always busy - ambulances come in and out, and gurneys rattle over the pavement as sliding doors whoosh open and closed behind sleep deprived paramedics. The crying cacophony of the waiting room sings out with every whoosh of the door. With it, you can feel the hope of those inside escape into the evening air.",
			"sound_path": "[groans of pain, wheeled gurney sounds]"
		}
	},
	"connected_zones": ["Ahuntsic-Cartierville", "Fleury Hospital: Triage"],
	"characters": []
},

"Fleury Hospital: Triage": {
	"zone_name": "Fleury Hospital: Triage",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The triage is loud, crowded and miserable. The flourescent lights add a level of jaundice to the cramped collective of ill and infirm.  Even the orderly who went breezing by smelling suspiciously like weed and alcohol seemed afflicted. The patients stare up at one TV with sagging eyes, and open mouths, watching a silent news anchor read the news with French Captions. A crackling voice goes out over the intercom, paging some member of the medical team to the ER.

There's an aging, burly nurse working the check-in and triage desk who's gossiping with another. You have the feeling she is the kind of no-nonsense nurse that knows how to pin you down, and give you a cavity search while enjoying it a little too much on her end. 

There is a sliding, automatic door leading outside to where a couple of unlit ambulances are parked.",
			"sound_path": "[someone coughing, baby crying, people arguing]"
		}
	},
	"connected_zones": ["Fleury Hospital: Exterior", "Fleury Hospital: Medical Ward", "Fleury Hospital: Hospital Room","Fleury Hospital: Elevator"],
	"characters": []
},

"Fleury Hospital: Medical Ward": {
	"zone_name": "Fleury Hospital: Hallway",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The halls of the hospital are boring and liminal - confusing and maze like. How long have you been stuck here? The smell of sterile medical plastic stings the nostrils when the lift doors open. There is a low rumble coming from the Nurses' Station as they take calls and prepare the next round of vitals, medication and getting yelled at by Doctors. The sounds of dozens of EKG machines bleep through the ward, accompanied by the the low rumble of the TVs in patients' rooms. In the distance, someone is crying.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Fleury Hospital: Triage", "Fleury Hospital: Labs", "Fleury Hospital: Hospital Room","Fleury Hospital: Elevator"],
	"characters": []
},

"Fleury Hospital: Labs": {
	"zone_name": "Fleury Hospital: Labs",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The smell of sterile medical plastic is strong here. This floor is brightly lit up, almost excessively so. This floor is entirely equipped to take all patient samples and give a full analysis with their microscopes and slides, test tubes, centrifuges, and auto-klaives. A couple of younger post-grad types are usually found in here at night. They quietly do their work with headphones covering their ears. The walls are adorned with charts and diagrams of science and human anatomy. There's a picture of some older gent in a white coat mounted to a dart board looking out at the room with a painfully paternalist expression.",
			"sound_path": "[beep of hospital equipment, air conditioning, heavy breathing?]"
		}
	},
	"connected_zones": ["Fleury Hospital: Medical Ward","Fleury Hospital: Elevator","Fleury Hospital: Pharmacy"],
	"characters": []
},


"Fleury Hospital: Hospital Room": {
	"zone_name": "Fleury Hospital: Hospital Room",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Though the room is private, you still feel exposed. Machines beep and hum, with medical implements and supplies carefully arranged in cupboards, bins, and glass containers. There is an attempt made at cleanliness here that escapes the more public areas of the hospital, but it is only surface deep. Looking closer, the trash bin is overflowing, the sharps container has used needles sticking out of it, and there is a stink in the exam table that just won't leave, filling your nose as you shift in your seat.",
			"sound_path": "[beeps, rolling chair noises, curtains opening, bed rustling, door closing]"
		}
	},
	"connected_zones": ["Fleury Hospital: Medical Ward", "Fleury Hospital: Triage"],
	"characters": []
},
# ---------- Fleury Hospital: Elevator Zone ----------
	"Fleury Hospital: Elevator": {
		"zone_name": "Fleury Hospital: Elevator",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The dingy light flickers as you enter the elevator, barely large enough to fit a gurney. The Muzak sofly emits from the small speaker coming somewhere from above your heads. The vertical panel of buttons, which look half rubbed off after years of use, show the available floors.Your arrival at a given floor is heralded by a chime, and a canned, static-filled voice calling out something unintelligible.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Fleury Hospital: Medical Ward", "Fleury Hospital: Triage", "Fleury Hospital: Morgue", "Fleury Hospital: B1", "Fleury Hospital: Labs"],
		"characters": [],
	},
# ---------- Fleury Hospital: Pharmacy Zone ----------
	"Fleury Hospital: Pharmacy": {
		"zone_name": "Fleury Hospital: Pharmacy",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The stench of the world's largest jar of daily vitamins strikes when the lift doors open. The hallway leading from the elevator to the tiny waiting room is very short. On the opposite side of this waiting room is a wall with a single, solid-looking security door made of metal, and a small 'drive-thru' window for the Pharmacists and Techs to take and fulfill prescriptions. There is a security camera for the door, the window and the sitting area with it's total of three uncomfortable looking chairs. It's very dark here. If anyone is working over night, they are way behind that solid, metal door.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Fleury Hospital: Labs"],
		"characters": [],
	},
	
# ---------- Fleury Hospital: B1 Zone ----------
	"Fleury Hospital: B1": {
		"zone_name": "Fleury Hospital: B1",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "It's quiet, short of the hum of something, maybe a furnace or heating system operating. There are a series of large exposed pipes and conduits running along the ceiling. Most of what is seen here are doors with various signs denying entry to those Not Authorized. One of them says, 'Security Personnel Only'.

The idling janitor carts in the hallways lead you believe maintenance and janitorial services begin, and end their shifts on this floor.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Fleury Hospital: Elevator"],
		"characters": [],
	},

# ---------- Fleury Hospital: Morgue Zone ----------
	"Fleury Hospital: Morgue": {
		"zone_name": "Fleury Hospital: Morgue",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "You immediately feel the cold when the doors to the lift open. It's quiet here too, dead quiet. It makes the sound of your footsteps louder than they probably should. The smell of water, sanitzing chemicals and humors gently waft through this floor.  The morgue is at the end of a long hallway that is dimly lit. One of the light ballasts house faulty bulbs that eerily flicker off and on. Passed a small desk, and through a door marked, 'Morgue' lies the whole operation; autopsies, post-morts, and freezers to preserve them until moved to their final resting places. A single, blanket covered corpse drains its fluid from a tube in its leg that sticks out from under the covers, into a large drain in the floor. The whole place is tiled in some dingy white and sea green hue like it was built in Florida during the 1960s,",
				"sound_path": ""
			},
		},
		"connected_zones": ["Fleury Hospital: Elevator"],
		"characters": [],
	},
	
	# ---------- Fleury Hospital: Graveworm's Lab Zone ----------
	"Fleury Hospital: Graveworm's Lab": {
		"zone_name": "Fleury Hospital: Graveworm's Lab",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Hidden among the many comdemned rooms of Fleury Hospital, this lab is as equipped as the true morgue, but with a drastically different purpose.

",
				"sound_path": ""
			},
		},
		"connected_zones": ["Fleury Hospital: Morgue", "Fleury Hospital: Corpse Elevator"],
		"characters": [],
		"secret_entry_passwords": ["gravy"],
		"accessible_from_zones": ["Fleury Hospital: Morgue"]
	},
# ---------- Fleury Hospital: Corpse Elevator Zone ----------
	"Fleury Hospital: Corpse Elevator": {
		"zone_name": "Fleury Hospital: Corpse Elevator",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "One of the regular elevators to the Morgue, perfect for the loading and disposal of bodies.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Fleury Hospital: Exterior", "Fleury Hospital: Graveworm's Lab", "Fleury Hospital: Morgue"],
		"characters": [],
		"secret_entry_passwords": ["corpse"],
		"accessible_from_zones": ["Fleury Hospital: Exterior"]
	},

###########################################

# ---------- Mercier Zone ----------
	"Mercier": {
		"zone_name": "Mercier",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This is where the island shows its bruises. Mercier was once a city unto itself, stretched thin along the river like a prayer that never got answered. Then it was annexed. Then it was forgotten. The factories and industry are mostly dead now. What remains is rust and routine, with the spaces that once held industry blooming with new growth - parks, gardens. The churches here echo too much. The schools look more like fortresses. And the alleys never stop steaming, even in winter. Poor but proud, French here is the mother-tongue, spoken raw and fast. Violence here does not sneak in; it stomps through the front door. Demonstrations against new industrial projects, fights in the metro, fires in the night. The local government throws up murals and food banks like wards against collapse. Something is growing in the cracks between these concrete slabs. Not a movement. Not a miracle. Just pressure. Roots buckling pavement, trying to tear off the modern facades and return to something greener.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Anjou", "Hochelaga-Maisonneuve", "Rosemont", "Montréal-Est"],
		"characters": []
	},

# ---------- Hochelaga-Maisonneuve Zone ----------
	"Hochelaga-Maisonneuve": {
		"zone_name": "Hochelaga-Maisonneuve",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This is where the island shows its bruises. Hochelaga was once a city unto itself, full of smokestacks and sweat, proud and ugly and loud. Like Mercier, it followed a similar fate. The factories are mostly dead now. Old unions. Old grudges. The backfiring of cars and the roar of biker gangs have replaced the clangs and shouts of industry. Saint Catherine Street East cuts through it like a vein that s been opened too many times. Here, it is the people who keep what little order there is, not the government. Eyes shift pass as groups meet in carefully selected restaurants. They look away as items change hands in an alley. The women on the corners are pretty and eager, waving at the cars and bikers passing by as they strut and show off the merchandise.

Nobody trusts each other much. Not the cops, not the landlords, not the neighbors. But they all know when to keep their heads down. Everyone knows someone who got jumped last week. Everyone knows which stairwells to avoid. Kids walk to school past boarded-up storefronts and act like they don t see the needles. It is a place that functions, barely, on muscle memory and spite.

Something builds beneath the worn-down exteriors and tired faces. You feel it in the way people glance over their shoulders. In the way they speak faster and listen less. The city marks this place as up-and-coming, but no one here believes in upward anymore. Just coming. Whatever it is, it is already on its way.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Mercier", "Rosemont", "Plateau Mont Royal", "Centre-Sud"],
		"characters": []
	},

"Montréal-Est": {
	"zone_name": "MontrealEst",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Montréal-Est sits by the oil tanks, where the river bends wide and chemical lights stain the night sky. The factories breathe steady, their chimneys spilling smoke that drifts like scripture across the dark. Streets here run flat and functional, lined with warehouses and small brick houses pressed close against chain-link fences. The smell of gasoline lingers in every doorway, and puddles catch neon from trucks rolling past like restless sermons.\n\nIt is an industrial parish, lit not by stained glass but by refinery flames that never die. The silence between shifts feels heavier than prayer, broken only by the hiss of valves and the groan of metal. In Montréal-Est, the city’s hunger is not romantic. It is mechanical, chemical, a machine that keeps running even when no one is watching.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Pointe-aux-Trembles", "Mercier", "Anjou"],
	"characters": []
},

"Côte Saint-Luc": {
	"zone_name": "CoteSaintLuc",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Côte Saint-Luc sits like a city within the city, bordered by rail yards and highways that close it off from the rest of the island. Apartment towers rise over brick duplexes and tidy lawns, anchored by the shopping centre where groceries and banks keep the pulse steady. It is a Jewish enclave, its synagogues and community halls setting the rhythm of life, the windows going dark early while bakeries and family shops stand as old guardians against the pull of downtown.\n\nAt night the neighborhood holds its breath. The streetlamps hum along Cavendish but their glow falters in the hedges and the alleys, leaving the silence thick. To the north, the rail yards stretch out like an open wound, cars resting in endless rows under the stars. The calm feels heavy here, not protective but suffocating, as if the stillness itself has weight. The quiet listens back, and something in it waits.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Lachine", "Côte-des-Neiges", "Saint-Laurent", "Dorval"],
	"characters": []
},



"Plateau Mont Royal": {
	"zone_name": "PlateauMontRoyal",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The Plateau is the city’s painted smile. Rows of spiral staircases and murals peeling like sunburn. It was once working class, then artistic, now both and neither. Everything here is façade. Painters drink with lawyers. Poets rent from hedge funds. The corner cafés smell like burnt espresso and rising rent. Meanwhile, Centre-Sud squats just beneath it, quieter and colder. A place where the bones of Old Montreal still show through the cracks.

They built this part of the city early, and they built it wrong. The sewers breathe at night. The air smells like old bread and forgotten blood.

The Plateau is already changing. Young francophones from the suburbs are moving in with stolen furniture and big ideas. English still lingers in Mile End and Saint-Louis Square, but it is the language of grandparents and landlords now. Immigrants are priced out one block at a time. The city loves to show off the Plateau, a “cultural beacon”...but those who live here know the beauty only goes skin deep.
",
			"sound_path": ""

		}
	},
	"connected_zones": ["Mont-Royal West", "Quartier des Spectacles", "La Petite-Patrie", "Hochelaga-Maisonneuve", "Centre-Sud", "McGill – Downtown Campus"],
	"characters": []
},


# ---------- Mont-Royal West Zone ----------
"Mont-Royal West": {
	"zone_name": "Mont-Royal West",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "It wears its past like a coat gone thin at the elbows. Once it was parades and bakeries, now it is pawnshops, cheap bars, and apartments that groan through the night. You catch the languages still layered in the brick, French laughter, Yiddish prayers, Irish curses, all pressed together into the same tired mortar. The street never stopped changing, it only collected scars. \n\nWhat was once promenade turned into corridor, each doorway a palimpsest. Priests smoked where students now drink, brass bands dissolved into synth beats, and the ghosts of corner cafés still linger behind the neon. Mont-Royal West does not tell its history. It forces you to walk through it, step by cracked step.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Jailhouse Rock Cafe Deck", "Plateau Mont Royal"],
	"characters": []
},



# ---------- JRC Venue Zone ----------
	"JRC Venue": {
		"zone_name": "JRC Venue",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The narrow store front betrays the reality of the space available inside the venue. The length of the venue was 30 meters long, making plenty of space for people on the inside.The walls are adorned with fliers of shows coming. Iconic shows that had already come were bound in a frame to be adored for all time. 

The  Wall of Elvi , a wall painted with Elvis in the Jailhouse, and all around him are pictures of world-renowned Elvis impersonators, including Pol Parsley THE Thai Elvis.

Bartenders worked behind a wooden, L-shaped bartop. They keep their cool while passing out dozens of drinks to the demanding public, scrambling for tips to make rent in the big city. 

Behind them are shelves of booze that flicker with the lights flashing, and strobing from the ceiling and stage. 

On the opposite side of the venue is the stage, and what seems like some sort of small hallway with a double hinged door swinging in and out as people regularly pass through. There is a homemade, wooden sign that says  Restrooms nailed to the front of the door. ",
				"sound_path": ""
			},
		},
		"connected_zones": ["Jailhouse Rock Cafe Deck", "JRC Hallway"],
		"characters": []
	},

# ---------- JRC Hallway Zone ----------
	"JRC Hallway": {
		"zone_name": "JRC Hallway",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This hallway is narrow, and much shorter than the rest of the venue s high ceiling. Tthere is a right turn leading to the Gents and the Ladies. A few feet further down leads to another room that is guarded by another bouncer when there is a show that night. When the way is clear, it leads to the Green Room for the big acts that came that way. It was also for the few people who were  cool enough  to know about it, and loiter there with some privacy.",
				"sound_path": ""
			},
		},
		"connected_zones": ["JRC Venue", "JRC Green Room"],
		"characters": []
	},

# ---------- JRC Green Room Zone ----------
	"JRC Green Room": {
		"zone_name": "JRC Green Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The Green Room (with red walls) is small, but adequate to comfortably hold the big acts and their various dalliances with a series of old, but clean and comfortable looking couches and chairs. A warm, dull light emits from a couple of lava lamps, and some white icicle Christmas lights draped all around at the tops of the walls.

There is a very old floor tom sitting on a small pillar. The hardware on it is a bit rusty, and the glitter finish drum wrap was losing its luster. But sticking out the side, near the bottom, was a spout. The pillar had a small plaque in front of it.

The plaque refers to how this was once a hidden room in a Canadian  speakeasy  when Montreal was one of the few safe havens for booze during Canadian prohibition. 
",
				"sound_path": ""
			},
		},
		"connected_zones": ["JRC Hallway", "JRC Stage"],
		"characters": []
	},

# ---------- JRC Stage Zone ----------
	"JRC Stage": {
		"zone_name": "JRC Stage",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The stage stands 1.5 meters above the venue floor. It s made entirely of long planks of wood like an old theater stage. There were old, red curtains with dingy gold trim, drawstrings and tassels draped at the front. They strangely smelled of popcorn, beer and fire. There is an array of black cables, and input boxes for the bands to plug into before sound checks. 
There is a rack of stage lights running across the front just behind the curtains that light up when a band is playing. A stage hand in the back controls it all with a few light and smoke contraptions they've got jury rigged together.

There is a trap door, but it doesn't seem to open from this side. No one knows how to open it, and get down under the stage. The stagehands figure the access under the stage was sealed off with a wall years before, and that it probably came out to the Green Room. ",
				"sound_path": ""
			},
		},
		"connected_zones": ["JRC Green Room"],
		"characters": []
	},

# ---------- Jailhouse Rock Cafe Deck Zone ----------
	"Jailhouse Rock Cafe Deck": {
		"zone_name": "Jailhouse Rock Cafe Deck",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The nearby sounds of downtown Montreal began to fall to the wayside as the sound of the crowd, and loud music of the Jailhouse Rock Cafe grew louder. 
The noise picks up the scent of booze, cigarettes, and cloves along with trace amounts of patchouli, sandalwood and pomade. A car passes by, and honks their horn at the people outside, raising their glasses and sending a  Wooo!  back to the passerby.

The front of this joint is an elevated deck standing a few feet above the sidewalk adjacent. It is loaded with tables, and people having a drink. A veritable French cafe for the greaser, the beatnik, the biker, the hippie and the head. All united under the banner of Rock and its last 40 years of life and evolution. 
There are fliers in the windows behind the tables to showcase plays there next.

When there was someone playing, the deck would be packed. So many came out to experience  the vibe  together, using booze and live Rock n Roll to forget about how horrible a place the real world is by listening to the music its oppressive atmosphere had created. Sometimes there would be a Burlesque show, or Rocky Horror night, but Rock n Roll was King at the Jailhouse Rock Cafe.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Mont-Royal West", "JRC Venue"],
		"characters": []
	},





# ---------- Centre-Sud Zone ----------
	"Centre-Sud": {
		"zone_name": "Centre-Sud",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Centre-Sud squats beneath the Plateau, waiting. Waiting for someone to notice. Centre-Sud remains what it was; bruised and patient. Home to the invisible, the addicted, the alone. There are community kitchens and punk shows and shelters with broken locks. Saint-Denis is all smoke and shouting on Friday nights. The alleys behind Ontario Street feel hungover before the sun even sets. 

Like the Plateau, this district is built on art, on culture - on the vibrance the people desperately infuse this place with, hoping that someone will see them and react with love instead of fear. It is a place of the deviant and the outcast, those who do not fit the mold of traditional society. It is the Gay Village - a quarantine from the rest of the city, where its residents are invited to a qualified freedom encased by careful walls.


No one talks about the overdoses in the Centre-Sud shelters. Or the nights when the power flickers and dogs will not stop barking. There are more fights lately. Not drunk, not petty. Just fast and final. A woman vanishes from her third-floor apartment. A man burns alive in an alley and no one hears a scream. It is as if the lights got too bright and started attracting the wrong kind of attention. ",
				"sound_path": ""

			},
		},
		"connected_zones": ["Quartier des Spectacles", "Plateau Mont Royal", "Downtown Montreal", "Hochelaga-Maisonneuve", "Old Montreal"],
		"characters": []
	},

# ---------- Karl's Apartment Zone ----------
	"Karl's Apartment": {
		"zone_name": "Karl's Apartment",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Found on the top floor of an old apartment building that near straddles the border between Centre-Sud and Plateau-Mont-Royal, the apartment is deceptive upon first entry. Upon entry one would think they've found themselves in a long hallway, its walls painted in psychedelic patterns and colors. One quickly realizes though that this isn't a hallway but two large painted bookcases, placed in a way that splits the large studio apartment roughly in half.

To the right, one would find themselves in a cramped living space. A  half clean kitchenette sits along the far wall, the sink filled with soaking brushes while the mint green fridge has erratic sketches tapped onto it. A small pantry door lies next to the kitchenette ajar, showing off that it is filled with clothes. Two tables, one a large dining table, the other a refurbished cards table, are expertly placed to make sure the space isn't too cramped. The dining table is circled by four wooden chairs and a leather recliner at its head. On the table lies a small eclectic collection of staked magazines and newspapers, along with paint stained bowls that contain art supplies in some. The card table in comparison only has a television set and a potted succulent. The separating bookshelf for this side is filled with is disorganized collection of sketchbooks, artist magazines, and books on subjects such as religion, folklore, history, and anatomy. A wall mounted phone sits alone on the back wall.

To the left lies a haphazard combination of bedroom and makeshift workshop. A large comfortable couch takes up most of the back wall, sitting between the dividing shelf and a door that lead to a bathroom that's been partially converted into a photo lab. From there in a clockwise manner sits a standing corkboard plastered with photos of seemingly random things. Next to it sit three easels of varying sizes with an endtable of paint supplies next them. Then after the easels is a small drafting table followed by another small table occupied by woodcarving tools. Finally, next to that is a third table occupied by sculpting, pottery, waxwork, and leatherworking tools. This side's dividing bookshelf covered in clutter of sketches, pottery, and homemade candles. None of the walls are left bare, as paintings of various styles, primarily baroque and expressionist, fill every space.

The studio smells dully of wet paint and wood smoke. The feeling one gets standing in it is both overwhelming yet welcoming. Chaotic yet understandable. Confusing yet inspiring. Perfect for the type of person who calls this place home.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Centre-Sud"],
		"characters": [],
		"secret_entry_passwords": ["Painter"],
		"accessible_from_zones": ["Centre-Sud"]
	},

# ---------- Théâtre de l'Aube: Entrance Zone ----------
	"Théâtre de l'Aube: Entrance": {
		"zone_name": "Théâtre de l'Aube: Entrance",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "
Welcome to the ironically named Theatre of Dawn.

The ticket booth stands empty but bright as ever, despite the dusty must that lingers about the foyer. Old posters are still hung up above it, and below a mock-stained glass decoration. Someone must be keeping the chandeliers and lanterns lit.

The waiting room seats are practically crumbling where they sit, the line of seats and lanterns above leading up to into a stairwell, and a locked door besides, with a long lost key. To the side of the booth stands the entrance into the grand theatre, just a short hallway walk away.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Centre-Sud", "Théâtre de l'Aube: Side Stairwell", "Théâtre de l'Aube: Grand Hall"],
		"characters": [],
		"secret_entry_passwords": ["Eclipse"],
		"accessible_from_zones": ["Centre-Sud"]
	},

# ---------- Théâtre de l'Aube: Grand Hall Zone ----------
	"Théâtre de l'Aube: Grand Hall": {
		"zone_name": "Théâtre de l'Aube: Grand Hall",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The former glory of this hall still runs strong, despite the loose debris on the floor and the torn, decaying curtains. 

Empty seats o’ plenty stand in rows, so unused and aged that a gentle touch threatens to tear the red fabric that holds the cushioning. Before them, a stage where once talents told stories and wowed crowds, now sits empty and unused. 

Above, more floors, more seats, with how dilapidated the building itself stands, one may lose themselves trying to find the way to the upper seats. Perhaps even when it bustled, this was an architectural issue with this theatre. Maybe a contributor to its inevitable abandonment in the future.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Théâtre de l'Aube: Backstage", "Théâtre de l'Aube: Entrance"],
		"characters": []
	},

# ---------- Théâtre de l'Aube: Backstage Zone ----------
	"Théâtre de l'Aube: Backstage": {
		"zone_name": "Théâtre de l'Aube: Backstage",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Behind the heavy curtains and stage sits this room, where actors and other talents used to prepare for their entrance. Now it’s a makeshift meeting room, lit with lantern and candle light, decorated with mirrors and various old furniture, mismatched chairs and stools. Expertly cluttered to look cozy despite the water damaged flooring. Another curtain, not the stage curtain one behind had been hung up to make the illusion of pretty and theatrical below a naked, skeletal ceiling.

One a small table sits a small box, in it, some well-rolled cigarettes and candies for those who can still relish the sweetness mortal teeth crave. In another corner, a hookah, an authentic one, too. 

The strong smell of incense over moss and rotting fabric sits in the musty, old building air.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Théâtre de l'Aube: Grand Hall"],
		"characters": []
	},

# ---------- Théâtre de l'Aube: Side Stairwell Zone ----------
	"Théâtre de l'Aube: Side Stairwell": {
		"zone_name": "Théâtre de l'Aube: Side Stairwell",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Have you been told to follow the lanterns? Perhaps you were, perhaps not. Perhaps you’re expected, or maybe you are an unwanted guest.

The stairwell is cramped, and yet it is clear someone put time and care to try and clean it and make it feel half cozy. It’s carpeted, but this is a carpet you can forget about, with one of those patterns so busy, they’re purposely made to hold dust and grime. 

Lanterns are strewn about along with small basins filled with scented oils. There’s a certain ritualistic air to the arrangement - but a personal ritual, rather than something inherently meaningful for a crowd of individuals.

The walls are half deteriorating - they are long past renovation, yet decorated with mirrors parallel to one another, causing some glances to make the space feel bigger and endless, quite purposely so.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Théâtre de l'Aube: Entrance", "Théâtre de l'Aube: Upper Loft", "Théâtre de l'Aube: Rooftop"],
		"characters": []
	},
# ---------- Théâtre de l'Aube: Upper Loft Zone ----------
	"Théâtre de l'Aube: Upper Loft": {
		"zone_name": "Théâtre de l'Aube: Upper Loft",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "As you enter, the floorboards groan beneath your feet, but it's the air that greets you first — It's stuffy in here. The scent of incense and lantern oil fighting to mask the unpleasant undertones of moss, rot and decaying velvet. The light is low but warm, cast by dozens of mismatched lanterns and candles tucked into alcoves, their glow pooling on faded murals. The shadows seem to squirm restlessly between the lanterns in the corner of your eyes, as though the excess lighting could only push rather than banish them.

Your steps echo, a reminder of the run-down and abandoned grand theatre below. Strewn about the floor are threadbare carpets, whose once vibrant colors and intricate patterns have turned dull and dusted. They mute your steps when you step on them — but they're not meant to be stepped on with shoes.

Exposed walls and maintenance what-nots are mostly-hidden behind shelves, furniture, most of it wood and most of it old. Nothing quite matches, yet it's clear someone tried to make do with what they got to craft at least an illusion of a cozy space. A stage is strewn in the middle of the loft, but it's seemingly made into a bedroom of carpet and pillows, with chairs carefully arranged. A platter of lit candles sits below the arch, illuminating it prettily – yet writhing shadows linger below. One curtain is folded, seemingly fixed and sewn halfway through with another that doesn't quite match. Another curtain, smaller, not meant for the stage, was left to cascade dramatically. The loft is moreso magnetic than welcoming. It demands attention. ",
				"sound_path": ""
			},
		},
		"connected_zones": ["Théâtre de l'Aube: Attic", "Théâtre de l'Aube: Side Stairwell", "Théâtre de l'Aube: Bathing Room"],
		"characters": []
	},
# ---------- Théâtre de l'Aube: Attic Zone ----------
	"Théâtre de l'Aube: Attic": {
		"zone_name": "Théâtre de l'Aube: Attic",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This rundown attic smells like dust and old paper. The woodboards groan violently at your feet on the first step, and grant you mercy on the next. Papers are in disarray, but somehow meticulously so.

A single lantern hangs at the ceiling, gently swaying with draft wind. Packed boxes, likely holding miscellaneous items from last century, gather dust in corners and shelves of the cramped attic room. The sloped feeling only serves to add to the claustrophobic feel.

On the table sits a jar of dirt, most notably, among all the paperworks and books. Despite everything else, the room looks lived-in. Whoever does live here is unbothered by the cramped space and musty, dusty air.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Théâtre de l'Aube: Upper Loft"],
		"characters": []
	},

# ---------- Théâtre de l'Aube: Bathing Room Zone ----------
	"Théâtre de l'Aube: Bathing Room": {
		"zone_name": "Théâtre de l'Aube: Bathing Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Someone worked tirelessly to make this even possible. There are basins strewn about, the largest one playing the role of a sink atop a shelf, with a small stool standing lonely besides. A mirror hangs in front, and above it, towels are seeming hung with the skeletons of the ceiling.

This was once a chemical room, but now, pipes have been exposed and bent and just one of them has a valve that actually runs water, albeit cold. For that, a heater stands in the corner - quite small, the type made for tea, but it seems to hold the metal basins strewn about quite well. Something between a small bathtub and a large basin sits against the wall, with a faucet that doesn’t actually work besides it and a mirror hung up on the wall above. 

Candles decorate the entire room, which smells sweetly of all the little metal and glass bottles of hair and body products, as well as other aromatics, some handmade, others squeezed out of their commercial bottles and into personalized ones.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Théâtre de l'Aube: Upper Loft"],
		"characters": []
	},

# ---------- Théâtre de l'Aube: Rooftop Zone ----------
	"Théâtre de l'Aube: Rooftop": {
		"zone_name": "Théâtre de l'Aube: Rooftop",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A sort of cozy, half balcony half bare rooftop overlooking the city of Montreal.

Carpets are strewn about, along with a book shelf and many loose piles of books only waiting to be picked up. Most in french, some in English. A small coffee table sits in the middle for use, but seems to usually be too cluttered. 

The skeleton of a canopy stands at the rails, and used to hang up various lanterns, adding to the cozy feel of this chill view of the city and night sky, and death trap for a cainite by day.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Théâtre de l'Aube: Side Stairwell"],
		"characters": []
	},





# ---------- Rosemont Zone ----------
	"Rosemont": {
		"zone_name": "Rosemont",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This district was built by hands that knew brick and mortar better than names. Rosemont came from the east, steady and working. You can still see the Catholic past in the rooflines and cross-streets. But that past has faded into smoke and discount signage. It was never rich, but it was solid. The kind of place that felt permanent. That permanence is starting to crack now. Paint peels. Foundations shift. The old families move out. Something colder moves in.

The streets are full of French. Real French. Blue-collar and loud. Mechanics, bakers, civil servants. Their kids drift between punk bars and Cégeps. The old Italian men still play cards behind the Jean-Talon Market. There is money here, but it does not show itself. It hides in toolboxes and pension plans. Rosemont is stubborn. La Petite-Patrie is watchful. Together, they are a district that knows how to wait. The kind of place that knows a storm is coming and puts plastic over the windows without being told.

It is getting worse. Slowly. Quietly. Fights that used to end with black eyes now end with hospital visits. Police cars idle longer than they used to. There are more broken bottles on the sidewalks. More glances that linger too long. A woman falls from a third-floor balcony and the neighbors agree not to mention it. A kid starts screaming in class and no one can calm him down. The city says this is a district in transition. That word hangs in the air like mold. This place was built by workers. But it is being unbuilt by something else. Something no one is naming yet.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Anjou", "La Petite-Patrie", "Saint Leonard", "Saint-Michel", "Mercier", "Hochelaga-Maisonneuve"],
		"characters": []
	},

# ---------- La Petite-Patrie Zone ----------
	"La Petite-Patrie": {
		"zone_name": "La Petite-Patrie",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Like Rosemont, this district was built by the working class. La Petite-Patrie sprouted behind it, row houses and corner shops in close formation. You can still see the shared Catholic past in the rooflines and cross-streets, the solidarity of first-wave immigrants beside the native Quebecois ever watchful.

The streets are full of French, Italians, and Vietnamese groceries that blink neon between barber shops, patisséries beside pizzarias. The money here is quiet, winding around the residential streets like the overgrowths of ivy. 

It waits for the storm to hit, bracing itself with hunched shoulders and firm backs against a rising tide. Slowly. Quietly. Fights overstay their welcome. Anger lingers and simmers, waiting for a moment to explode out. There is more broken glass on the sidewalks. Like Rosemont, the word 'transition' lingers in the air like mold, creeping into lungs already taxed and straining. La Petite-Patrie's immigrants wonder if this new tide will be the one to force them out, but they refuse to go without a fight.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Villeray", "Hochelaga-Maisonneuve", "Parc-Extension", "Rosemont", "Plateau Mont Royal", "Saint-Michel", "Boulevard St-Laurent"],
		"characters": []
	},
# ---------- Boulevard St-Laurent Zone ----------
	"Boulevard St-Laurent": {
		"zone_name": "Boulevard St-Laurent",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A road clogged with the scents of car exhaust and desperation.",
				"sound_path": ""
			},
		},
		"connected_zones": ["La Petite-Patrie", "Le Petit Alchemiste Storefront"],
		"characters": []
	},

# ---------- Le Petit Alchemiste Storefront Zone ----------
	"Le Petit Alchemiste Storefront": {
		"zone_name": "Le Petit Alchemiste Storefront",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The storefront of an alternative healing shop. Strong scents of bitter, fragant herbs assault the nostrils while glittering crystals cultivate the eye.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Boulevard St-Laurent", "Le Petit Alchemiste Interior"],
		"characters": []
	},

# ---------- "Le Petit Alchemiste Interior" Zone ----------
	"Le Petit Alchemiste Interior": {
		"zone_name": "Le Petit Alchemiste Interior",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A dimly lit shop. Dried herbs of all kinds hang from the ceiling, while others are contained in jars. Crystals decorate every flat surface, and behind the counter there are countless oils. Despite being a decently sized store, the clutter makes it feel small, nearly claustrophobic.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Le Petit Alchemiste Storefront"],
		"characters": []
	},

# ---------- The Prep Room Zone ----------
	"The Prep Room": {
		"zone_name": "The Prep Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A dark room lit only by a single, dim bulb. Behind the locked door which seperates the rest of the store, this room contains not only herbal remedies in the process of being made, but several psychoactive substances and cannabis, all hidden in the little corners of the room.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Le Petit Alchemiste Interior"],
		"characters": [],
		"secret_entry_passwords": ["OfficeKey"],
		"accessible_from_zones": ["Le Petit Alchemiste Interior"]
	},
	
# ---------- Villeray Zone ----------
	"Villeray": {
		"zone_name": "Villeray",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "These are worker streets. Narrow, lined with triplexes and concrete yards, hung with laundry in summer and cigarette smoke in winter. Villeray sits quiet and tense, built on factory time and stubbornness.

Something is pressing in.

 Out of the entire island, this is where people crowd up the most. French and English are spoken, but neither leads. Greek, Urdu, Tamil, Bengali, Punjabi, Arabic, Creole, Italian. The families here live tight. Some whole buildings speak the same language. Others shift from floor to floor.

The rent is cheap. The jobs are scarce. There are playgrounds with broken swings and community centres with flickering lights. No one here believes in help. Only endurance.

 Lately, even that feels strained. The police do not come quickly. When they do, they ask the wrong questions. Old men walk here at night with knives in their pockets, waiting for the other shoe to drop.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Ahuntsic-Cartierville", "Saint-Michel", "La Petite-Patrie", "Parc-Extension"],
		"characters": []
	},

# ---------- Parc-Extension Zone ----------
	"Parc-Extension": {
		"zone_name": "Parc-Extension",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Parc-Extension pulses like a fever, crammed with storefronts and stories in twenty languages. None of these neighborhoods were designed for grace. They were designed for function. Now that function has started to slip. The sidewalks crack. The windows fog. Something is pressing in. This side of the city always belonged to the newly arrived. Villeray and Saint-Michel are a few years ahead on the curve, but not by much. French, English, Italian and Greek, are all less spoken here than Hindu, Tamul, Bangla, Spanish, and Creole.

There are fights in the metro. Screams behind closed doors. A teenager dragged into a side alley and never seen again. People vanish between job shifts. This part of the city does not ask for safety. It asks only that the danger keeps moving.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Villeray", "Saint-Laurent", "La Petite-Patrie", "Plateau Mont Royal", "Ahuntsic-Cartierville", "Côte-des-Neiges"],
		"characters": []
	},

# ---------- Sud-Ouest Zone ----------
	"Sud-Ouest": {
		"zone_name": "Sud-Ouest",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This is where the city did its labor. Saint-Henri, Pointe-Saint-Charles, Little Burgundy, Ville- mard, Côte-Saint-Paul. Every name is a scar. The Lachine Canal carved through it like a wound that never closed. They built factories here. Textiles, metal, slaughter. The men died early, the women died quiet, and the city took their labor without gratitude. When the canal died, the silence was immediate. Trains stopped. Doors locked. Rats came back. No one cleaned up. They just painted over the brick and hoped no one would ask questions.

These nights, the Sud-Ouest holds on with white knuckles. Some houses are still owned by the families that built them. Others rot behind chain-link fences and foreclosure notices. French, mostly. Old stock, stubborn. But Haitian families have started to fill the cracks. So have Vietnamese and Irish remnants. Black youth keep to Little Burgundy, out of habit more than hope. English lingers here, but it feels apologetic. These streets do not belong to optimism. They belong to routine. People go to work. People get drunk. People survive. Sometimes that is all.

The violence is not new here. It just changed tone. It used to be shouted. Now it whispers. A stabbing on Charlevoix. A house fire that leaves no one accounted for. A fight in a park that ends too quietly. The police come slower. They ask fewer questions. No one wants to know why the canal smells different after midnight. No one investigates the shoes found tied together on the abandoned bridge. The city has plans. Murals, condos, bike paths. But the ground refuses to heal. Something old still walks here. It remembers the machines. It remembers the blood.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Lachine Canal", "Montreal West", "Westmount", "Notre-Dame-de-Grâce", "Downtown Montreal", "Old Montreal", "Pointe-du-Moulin", "Verdun", "LaSalle"],
		"characters": []
	},

# ---------- Anjou Zone ----------
	"Anjou": {
		"zone_name": "Anjou",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Anjou sits at the far edge of Montreal like a half-forgotten outpost, caught between the remnants of farmland and the tightening sprawl of highways. Its streets carry the weight of suburban ambition turned brittle: rows of low-rise apartment blocks with their paint sun-bleached and peeling, modest bungalows pressed shoulder to shoulder, and concrete shopping plazas where neon signs buzz faintly, letters missing or flickering out one by one.

In the quiet corners an abandoned lot where weeds push up through fractured pavement, the underpass where lights always flicker out too quickly there is a sense that something else has taken root. Not openly, not visibly, but as a whisper threaded through the hum of fluorescent lights and the endless drone of highway traffic. People rarely linger in these places without reason. The neighborhood seems to breathe in its own uneasy rhythm, as if hiding something beneath its surface, something that had been buried but never stayed still.",
				"sound_path": ""

			},
		},
		"connected_zones": ["Mercier", "Saint Leonard", "Rivière-des-Prairies", "Rosemont", "Montréal-Est"],
		"characters": []
	},

# ---------- Pointe-aux-Trembles Zone ----------
	"Pointe-aux-Trembles": {
		"zone_name": "Pointe-aux-Trembles",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Point-aux-Trembles breathes like a place on the fringe, pressed against the St. Lawrence, where the river wind carries both salt and rot. The streets stretch long and uneven, lined with squat duplexes and tired apartment blocks whose bricks have darkened with soot and years of weather. Paint peels from wooden balconies; laundry flaps on sagging lines even in the winter air, stiff and grey.

Factories loom close to the water, their chimneys coughing smoke into the sky, shadows falling across rows of chain-link fences where the grass grows in tufts through cracked pavement. At night, the yards are seas of sodium light, orange halos spilling over pallets, rusted drums, and puddles of oily rainwater that ripple though nothing moves nearby. The hum of machinery is constant, though it shifts in pitch without warning, as if responding to something unseen.

On the main streets, corner dépanneurs glow with buzzing fluorescents, casting sharp light onto faces that linger outside too long, half-hidden in the smoke of cheap cigarettes. Stray dogs bark in the distance, then fall silent all at once, as though commanded. Kids trade whispered dares about the abandoned houses near the riverbank, where windows gape like missing teeth and the wind rattles doors that should not be able to move.

The sense of decay is not just in the rusting metal and crumbling stone but in the air itself, heavy with a kind of expectancy. You can feel it when you step beneath the flickering lamps of an underpass or pause at the mouth of an alley where the asphalt splits into darkness. It is the hush before something stirs, the uneasy awareness that the neighborhood is watching that behind the broken facades and empty lots, Point-aux-Trembles keeps its own secrets, and they are not all of this world.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Rivière-des-Prairies", "Montréal-Est"],
		"characters": []
	},

# ---------- Rivi re-des-Prairies Zone ----------
	"Rivière-des-Prairies": {
		"zone_name": "Rivi re-des-Prairies",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Rivière-des-Prairies feels like a boundary more than a neighborhood, caught between the suburban sprawl of Montreal and the wide, black breath of the river itself. The streets stretch long and quiet, dotted with duplexes and modest brick homes, their lawns patchy with crabgrass and oil stains from cars that sit idle too long. The air is thick with humidity in summer, carrying the smell of cut grass mixed with diesel from passing buses. In winter, the snow turns grey within days, piled high against chain-link fences and littered with cigarette butts.

The blocks near the industrial edge echo with silence once the workday ends warehouses shuttered, loading bays left in shadow, only the occasional rattle of a loose sheet of tin breaking the stillness. Stray cats slip through broken windows, and in the evenings, kids dare each other to climb the fences and peek inside. They swear the buildings hum even after the machines shut down, a low vibration felt more in the chest than the ears.

Closer to the river, the atmosphere thickens. The water moves slowly, reflecting dull streaks of light from factories upriver, and the reeds at the shoreline rustle even when the wind is still. Abandoned docks sag into the current, their planks slick with algae, their iron bolts corroded like rotting teeth. Locals say you can sometimes hear voices carried over the water at night faint, disjointed, never close enough to understand.

The neighborhood carries a strange hush after dark. Streetlights flicker, casting uneven pools of light onto sidewalks where weeds force their way up through cracks. The silence is fragile, always on the verge of breaking: the distant slam of a dumpster lid, the squeal of rusted brakes, the sound of footsteps that don t quite match your own. Rivière-des-Prairies feels like it is waiting, holding something just out of sight. Its decay is ordinary enough to ignore by day, but at night, it sharpens into something else a sense that beneath the concrete, the water, the long streets leading nowhere, something old and restless has not been forgotten.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Pointe-aux-Trembles", "Anjou", "Montréal-Nord", "Montréal-Est"],
		"characters": []
	},

############################################


"LaSalle": {
	"zone_name": "LaSalle",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The river doesn’t slow for LaSalle. It rushes past in white curls and deep channels, shaping the land long before streets were drawn across it. The Lachine Rapids churn just beyond the parks, loud and constant, a reminder that this place was once the end of the line for canoes and cargo. The old canal still cuts through the landscape, half-forgotten but never erased. You can walk its length and feel where the city once stopped.\n\nLaSalle grew in pieces. Farmland gave way to industry, then to neighborhoods built for workers who wanted something stable, something theirs. Rows of brick duplexes stretch toward the horizon, their balconies stacked with chairs, flags, and flowerpots. Churches rise beside depanneurs. Schools hum with French, but the voices inside speak Italian, Haitian Creole, and Arabic after the bell rings. The land here holds stories, not landmarks. The rapids keep moving, the wind carries grit off the water, and people learn early how to plant their feet. This town does not wait for the city to notice it. It never needed to.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Lachine Canal", "Lachine", "Montreal West", "Verdun", "Sud-Ouest"],
	"characters": []
},


"Verdun": {
	"zone_name": "Verdun",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Verdun breathes in smoke and river mist, a quarter that never quite dries. Neon lingers on wet asphalt, caught in puddles that ripple when the metro rumbles beneath. The balconies lean close, iron railings rusted, laundry left to stiffen in the damp air. You can hear the Saint-Lawrence at night, low and endless, carrying the weight of everything dumped into it. Bars spill their glow out onto cracked sidewalks, tired jukebox songs leaking into the street, as if the river itself had learned to hum along.\n\nThe churches stand tired, their colored glass washed pale by fluorescent glare. Graffiti scrawls climb their walls like unanswered prayers, while bridges murmur with traffic above. In Verdun, nothing is hidden. Every scar is shown in light, every sin painted in color. It feels like the city watching itself in a mirror too long, seeing the cracks, and deciding to keep them.",
			"sound_path": ""
		}
	},
	"connected_zones": ["LaSalle", "Sud-Ouest"],
	"characters": []
},



"Saint-Laurent": {
	"zone_name": "SaintLaurent",
	"default_viewpoint": "main",
	"category": "montreal_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Saint-Laurent sits in the shadow of the mountain, not beneath it but behind it, just far enough that the weight of it feels muted. The old roads tilt east toward downtown, toward the spires and glass, but here the skyline breaks into smokestacks and satellite dishes. The factories still operate. The streets are built for trucks. Diesel clings to the air like a second language.\n\nBehind the wide boulevards, the town folds into itself. Armenian bakeries next to corner mosques. Casseroles cooling on balcony railings. French is spoken first, but no one expects it to be the last word. Saint-Laurent is protected by distance, by zoning, by memory. The mountain looms, yes, but it does not reach this far. Out here, the city feels imagined. Something told in stories. What is real are the loading docks, the church basements, the voices that slip between languages without pausing. The work begins early. The silence lasts longer. No one looks back unless they have to.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Ahuntsic-Cartierville", "Côte-des-Neiges", "Côte Saint-Luc", "Parc-Extension", "Pierrefonds", "Dollard-des-Ormeaux", "Dorval", "Lachine"],
	"characters": []
},




"Dorval": {
	"zone_name": "Dorval",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "You hear it before anything else. The drone of engines, constant and shifting, leaking through drywall and window frames. In Dorval, flight is not spectacle. It is weather. Planes cut the sky in tight descent, low enough to read the logos on their bellies. The air smells faintly of kerosene, especially near the highway, where hotels cluster like tired ideas.\n\nThis is not suburb or city. It is a threshold. The houses are older than they look, built before the island filled out. There are stretches near the lake where the grass grows long and the mailboxes still bear the names of families who arrived before Expo. People here are used to noise, used to being mistaken for something else. French and English pass without friction, often in the same breath. Dorval moves with a particular kind of patience, shaped by departure, but never in a rush to go anywhere.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Pointe-Claire", "Dollard-des-Ormeaux", "Lachine", "Saint-Laurent"],
	"characters": []
},



"Roxboro": {
	"zone_name": "Roxboro",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Rust clings to the railings by the tracks. Gravel shifts underfoot where the platform ends near a graffitied fence. Roxboro was laid down around the rail line, a town shaped more by schedule than plan. Bungalows lean into each other along narrow lots, their paint faded, their hedges trimmed low enough to see who still lives there. The river sits behind it all, screened off by brush, wires, and forgotten footpaths.\n\nThis is a place that never pretended to be polished. Roxboro holds onto its renters, its lifers, its names scrawled into wet cement behind the dépanneur. French and English mingle without effort, not because of tolerance but because there is no room for distance. Flags hang in front windows, not for pride, but to remember where someone came from. Children play in gravel lots with cracked plastic toys. The train passes through on time. No one waits for it, but everyone knows when it’s late.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Sainte-Geneviève", "Dollard-des-Ormeaux", "Pierrefonds"],
	"characters": []
},


"Dollard-des-Ormeaux": {
	"zone_name": "DollardDesOrmeaux",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The streets are wide and freshly paved, curving through rows of low brick homes and clipped front lawns. Street signs are clean, intersections marked by stop signs that everyone obeys. Sprinklers tick in unison at dusk. Nothing looks old here, and nothing looks like it plans to change. Dollard-des-Ormeaux was built for comfort, and it holds that shape carefully.\n\nFamilies came for order and stayed for insulation. Jews from Côte-Saint-Luc, Italians from the east end, Anglos who wanted nothing to do with referendum or downtown noise. French is there, but softened, more bureaucratic than cultural. Strip malls hold kosher butchers beside dollar stores and tailor shops, all under the hum of sodium lights. There are no landmarks, no nightclubs, no reason to visit unless you belong. And for those who do, that is exactly the point.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Sainte-Geneviève", "Pointe-Claire", "Kirkland", "Roxboro", "Dorval", "Saint-Laurent"],
	"characters": []
},



"Sainte-Geneviève": {
	"zone_name": "SainteGenevieve",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The stone church looks too large for the neighborhood. Built in the 1840s, its bell tower rises above the rooftops, watching the river like it remembers something the houses forgot. Sainte-Geneviève holds close to the shoreline, its streets laid along the routes oxen once dragged wheat to the old watermill. The bones of the parish run deep. Some of them are still in the crypt, beneath the church floor, where the founder was entombed after his body was brought back and buried again.\n\nFrench is spoken here without hesitation. Not out of pride, but because it always has been. The houses are modest, stone and wood, quiet behind hedges. Rain sticks to the pavement longer than it should. The river glows faintly at night, not from the city, but from something older... Nothing about Sainte-Geneviève feels abandoned, but it feels remembered in a way that most places are not.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Pierrefonds", "Kirkland", "Dollard-des-Ormeaux", "Roxboro"],
	"characters": []
},


"Pointe-Claire": {
	"zone_name": "PointeClaire",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Old stone still clings to the shoreline where the mission once stood, its church tower watching the lake with the same silence it always has. Just uphill, the streets begin to twist into something else. Split-level homes with aluminum siding, old trees boxed in by sidewalks, a tired shopping centre that still smells like carpet and popcorn. Pointe-Claire grew outward from the lake like a memory trying to modernize, layer by layer, decade by decade.\n\nIn the bars near the train tracks, accents blur together over cheap pints and jukebox hum. Teenagers drift between arcades and depanneurs, pockets full of change and nowhere in particular to be. French and English trade places without warning, depending on who is speaking and who is listening. The lake is always near, even when you cannot see it, pulling at the edge of things. Not a threat. Just a reminder.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Kirkland", "Beaconsfield", "Dollard-des-Ormeaux", "Dorval"],
	"characters": []
},

"Pierrefonds": {
	"zone_name": "Pierrefonds",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The lawns are wide in Pierrefonds, and the streets curve just enough to feel planned. Split-level homes line the blocks like teeth, all brown brick and vinyl siding, with porches big enough for folding chairs but not conversation. Kids ride battered BMX bikes in lazy circles, cutting through backyards and construction lots that never seem to finish what they started.\n\nIt’s a family place, mostly. Francophone and immigrant, with schoolyards that echo in four languages and Catholic churches that still fill on Sundays. There’s no nightlife worth naming. Just basements with wood paneling, pool tables, and cassette decks that never left the eighties. You might see the river from the end of your street, but most don’t bother. The city is far enough away to ignore, and close enough to blame when things don’t work. Pierrefonds keeps its head down and stays where it is.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Sainte-Geneviève", "Kirkland", "Senneville", "Sainte-Anne-de-Bellevue"],
	"characters": []
},

"Beaconsfield": {
	"zone_name": "Beaconsfield",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Something about the air feels thinner here. Not colder, just distant. Beaconsfield runs along the water, all quiet streets and careful wealth, where the houses sit back from the road as if uninterested in being seen. Trees are older than most of the homes, and the wind off Lake Saint-Louis moves through them like a habit. You can walk for blocks without hearing anything but your own footsteps and the low buzz of a streetlamp struggling to stay lit.\n\nEnglish dominates, but softly. This is old West Island money, not flashy, not loud. The kind that votes, keeps records, and teaches its children to speak properly. The train still stops here, though fewer people take it. Teenagers gather in parks lit just enough to see each other’s faces, drinking quietly, pretending not to belong. The shoreline is always close, dark and flat, reflecting little. Some nights it feels like the whole town is listening to the water, waiting for something to rise out of it.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Baie-D'Urfé", "Kirkland", "Pointe-Claire", "Sainte-Anne-de-Bellevue"],
	"characters": []
},


"Kirkland": {
	"zone_name": "Kirkland",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The streets were carved out in the 60s, laid over farmland and windbreak forests that once split the West Island into long forgotten concessions. By the 80s, the fields had vanished beneath cul-de-sacs and carports, filled with engineers, bureaucrats, and oil company men who wanted distance without disconnection. The roads are broad and clean, the lawns watched over. Nothing out of place, but the silence lasts too long after dark.\n\nEnglish is spoken without apology here. The churches are Anglican or United, the high school mascots are in English, and the community centres still serve coffee from chipped mugs with Union Jacks printed on the side. French is present, but only where it has been required. Behind the symmetry and suburban calm, there is an unease that lingers. Not loud, but constant. Porch lights flicker on at the same time every evening. No one answers the door if you knock too late. This is Kirkland. It behaves itself. It expects you to do the same.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Sainte-Geneviève", "Sainte-Anne-de-Bellevue", "Pierrefonds", "Beaconsfield", "Pointe-Claire", "Dollard-des-Ormeaux"],
	"characters": []
},
# ---------- Morgan Arboretum Zone ----------
	"Morgan Arboretum": {
		"zone_name": "Morgan Arboretum",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A derelict cabin that was used in the past as a stockpile and resting station for city services, abandoned after the city expanded. Quite near the forested area around the Ecomuseum Zoo


This is Yvonne Morgan's haven.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Kirkland"],
		"characters": [],
		"secret_entry_passwords": ["greyarboretum"],
		"accessible_from_zones": ["Kirkland"]
	},

"Sainte-Anne-de-Bellevue": {
	"zone_name": "SainteAnneDeBellevue",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The locks move first. Slow, deliberate, louder than you expect. Then the canal breathes, and the street picks up again. Sainte Anne de Bellevue is built around that rhythm. Stone underfoot, water to the left, cafés and brick storefronts to the right. Trains pass above without stopping. Boats pass below without hurrying. Everything here continues at the pace of conversation.\n\nMornings begin with brooms on doorsteps and gulls overhead. By noon the students have taken over the patios, and by night the lights reflect in the canal like they always have. Locals nod to each other without words. Strangers are noticed, not judged. The town holds a little warmth in its walls, the kind that doesn’t need to announce itself. The kind that stays after the last boat pulls away.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Kirkland", "Senneville", "Pierrefonds", "Baie-D'Urfé"],
	"characters": []
},

"Baie-D'Urfé": {
	"zone_name": "BaieDUrfe",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Wind moves freely in Baie-D’Urfé. It rolls in off the lake and settles in the trees, rustling through quiet streets that follow the curve of the water. The roads are narrow, the houses spaced out, and the lawns kept with a kind of careful modesty. There are no corner stores or glowing signs. Just mailboxes, fences, and the long sound of tires moving slow over wet asphalt.\n\nFounded as a farming parish in the early 1700s, the town still carries a sense of distance from the city it borders. Most residents have been here for decades. They know the shape of the shoreline and the timing of the train that cuts behind the marina. Children ride their bikes past trimmed hedges. Dogs bark from behind gates. Down by the docks, sails are lowered with practiced hands. It is the kind of place where very little changes, and the things that do are noticed immediately.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Sainte-Anne-de-Bellevue", "Beaconsfield"],
	"characters": []
},


"Senneville": {
	"zone_name": "Senneville",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Senneville holds the western tip of the island where the French first built their palisades in the seventeenth century. The fort has vanished, but the pattern of retreat endures. Wealth gathered here in the twentieth century, poured into large estates and careful gardens, then thinned and left behind mansions with hollow windows staring out across the water. The Saint Lawrence presses against the shoreline, steady and cold, gnawing at what inheritance once tried to preserve.\n\nThe people who remain live behind hedges and gates, professors from the city, heirs clinging to their parents’ property, families that wanted distance more than neighbors. Their streets are wide and still, patrolled only by the occasional car, each engine echoing in the silence. At the shore the docks sag into the current, boathouses marked by moss and fading paint. Senneville is not empty, but it feels rehearsed, as if everyone here is performing wealth long after the audience has gone home.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Sainte-Anne-de-Bellevue", "Pierrefonds"],
	"characters": []
},



######################## Ottawa ############################################

######################## Ottawa Downtown #################################

	"Ottawa Downtown": {
		"id": "OttawaDowntown",
		"default_viewpoint": "Main",
		"category":"ottawa_high_outside",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The streets stretch out in orderly rows, their lamps casting warm pools of light against the mist. Parliament stands steady above it all, its tower a familiar silhouette against the deepening sky. Flags stir dutifully in the damp air, and the old stones hum with the comfort of rituals well-kept. Every step echoes with the assurance that the city endures, unchanged and unwavering.\n
	Yet behind the glow of the windows and the tidy facades, something quieter moves — a slow settling of walls, a faint ache in the iron bones of monuments. The ceremonies continue without fault, the stones recite their oaths without pause, and no one speaks of the hairline cracks spidering just beneath the surface.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Parliament Hill", "National War Memorial", "Lyon Street - Downtown", "Lowertown", "Centretown West", "Centretown", "Sandy Hills"],
		"characters": []
	},

	"Parliament Hill": {
		"id": "ParliamentHill",
		"default_viewpoint": "Parliament Building",
		"category":"ottawa_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"Parliament Building": {
				"image_path": "",

				"description": "Parliament holds itself with care. The tower rises through the mist with the posture of something aware of being watched. Its copper crown is bruised, its windows emptied of light, but the silhouette remains firm. A gesture of continuity more than authority. Nothing has fallen. That is what matters.\n
	There are guards, of course. A few in plain view, jackets buttoned, boots clean. Others blend into the marble and shadow, lingering in alcoves you might not have seen until too late. They do not speak. They do not shift. But if you hesitate near the wrong threshold, someone always steps out. Not abruptly. Just on time. The city does not like questions.",
				"sound_path": ""

			},
			"Centennial Flame": {
				"image_path": "",

				"description": "Lit in 1967 for Canada’s centennial, the flame has never gone out. It sits openly at Parliament’s feet, encircled by quiet fountains and forgotten heraldry. By day it is photographed, maintained, respected. No one questions it. Not the tourists. Not the guards. Not even the Kindred, though many avoid it entirely. Some simply walk wider circles. Others tremble without knowing why.\n
	More than a few have succumbed to Rötschreck near its edge, overtaken by a terror that surges without warning. Still, the flame remains. Even the Prince has never proposed extinguishing it. Perhaps it is too visible. Perhaps too old. Or perhaps it is simply easier this way. The city endures many things it no longer understands, and the flame has learned how to be one of them.",
				"sound_path": ""

			},
			"Eyeing West Block": {
				"image_path": "",

				"description": "The West Block does not call attention to itself. Its towers wear age convincingly. The stones are dark in the right places, the windows recessed just enough to suggest old depth. Everything about it has been maintained with care. Too much care. It is the most heavily renovated of the triplet, and the most heavily trusted. That trust has never been questioned.\n
	Of the three, it is the most sinister. Not because of anything visible, but because nothing is. The air inside is muffled, as if the building prefers to keep voices soft. Corridors run longer than they should. Rooms appear on no floor plan but are never locked. Its silence is not reverent. It is deliberate. If something listens from inside the stone, it does not hide. It simply waits.",
				"sound_path": ""

			},
			"Eyeing East Block": {
				"image_path": "",

				"description": "The East Block wears its history like a uniform. Stone gables, arched windows, iron flourishes at the roofline. Everything cut to the silhouette of Victorian memory. Of the three buildings, it is the one that wants to be seen. Guides call it the oldest, the most authentic, the true anchor of the Hill. Its halls are dimly lit, lined with reconstructed offices meant to preserve the image of a government that once knew exactly what it was doing.\n
	Out front stands the 1812 memorial, cold and clean, flanked by chain posts and quietly ignored. No one visits it for long. It casts no shadow on the façade behind it. The building remains pristine in photographs, but those who walk by at night often feel watched. Not with hostility. With expectation. Like a stagehand behind the curtain, waiting for a cue that never comes.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Library of Parliament", "Parliament Building – Entrance Hall Zone", "National War Memorial", "Ottawa Downtown"],
		"characters": []
	},


	"Library of Parliament": {
		"zone_name": "LibraryOfParliamentMainHall",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The library stands behind Parliament like a reliquary, braced with flying buttresses and carved with the confidence of a nation that believes its own myth. No one questions its placement. Few enter without permission. Its dome rises like a crown of spires, steep and sharp, surrounded by walls that once suggested sanctuary. Now they suggest containment.\n
	This is not where knowledge is stored. This is where it is performed. The books are real, the archives vast, but the power lies in what is not indexed. Even Kindred tread lightly here, for it is Elysium. The city does not flaunt the building’s authority. It simply allows the illusion of scholarship to do the work. A masquerade of heritage, perfectly preserved. The only thing older than the records is the need to control them.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Library of Parliament – Main Chamber Room", "Parliament Hill"],
		"characters": []
	},

"Library of Parliament – Main Chamber Room": {
	"zone_name": "LibraryOfParliamentMainChamberRoom",
	"default_viewpoint": "main",
	"category":"",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The main chamber is a circle, but not a perfect one. Every architect’s drawing claims otherwise, and every visitor swears it feels off. The bookshelves rise in tiers along the curved wall, their spines uniform in height, untouched by time, like rows of waiting eyes. Desks are arranged in precise order across the floor, none of them facing each other, none quite aligned. Globes sit on some, unmoving. Others are covered in documents that have not been opened in decades, but are replaced exactly when one is removed.\n
The statue in the center does not point, gesture, or look. It simply exists, still and immense, standing where the acoustics collapse. Voices die at its feet. Lights hang far overhead, swaying slightly even when the air is still. The room smells faintly of heat and copper, like a place that used to house something alive. Every sound here happens a second too late. Footsteps echo before they land. Papers flutter without motion. No one reports these things. No one has to. The room is a safe haven. You are not in danger. You are only being watched by the shape of memory, wrapped in stone, waiting to see which thought you were about to have next.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Library of Parliament"],
	"characters": []
},


"Parliament Building – Entrance Hall Zone": {
	"zone_name": "ParliamentBuildingEntranceHallZone",
	"default_viewpoint": "main",
	"category":"",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The entrance hall is taller than it needs to be. The ceilings arch upward like a question held too long. The marble is cold underfoot, polished smooth but never reflective. At night, the chandeliers do not flicker. They hum softly instead, like something mechanical trying not to be noticed. The walls hold no clocks, no signs, no sense of direction. Just corridors, unfolding in angles that should return but never quite do.\n
The silence is not heavy. It is precise. Every footstep confirms you are somewhere you were not supposed to find on your own. The doors are too far apart. The arches are too similar. You keep moving, just further in. The stillness of the empty halls do not contain you, do not pull you back.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Parliament Hill"],
	"characters": []
},


	"National War Memorial": {
		"zone_name": "NationalWarMemorial",
		"default_viewpoint": "main",
		"category":"ottawa_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The National War Memorial rises with deliberate weight, too large for the square that holds it. Bronze soldiers march forward beneath the stone arch, locked in motion toward something long gone. The eagle above looks down, wings outstretched like a verdict. This is not a monument to the fallen. It is a structure meant to be obeyed.\n
	The buildings around it lean back slightly, as if pretending not to listen. Lights stay on too late. Traffic softens without cause. Just beneath the arch lies the Tomb of the Unknown Soldier, perfect in its placement, nameless by design. It marks nothing. It secures everything. The city wraps around it with careful choreography, rehearsing a silence it no longer questions.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Parliament Hill", "National Arts Centre", "Ottawa Downtown"],
		"characters": []
	},


	"National Arts Centre": {
		"zone_name": "NationalArtsCentre",
		"default_viewpoint": "main",
		"category":"ottawa_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The National Arts Centre is not like the others. It follows the rules of civic architecture only loosely, as if designed by someone who read the manual and chose to interpret it. Concrete spreads out in deliberate planes, severe and low, but inside there are moments of softness, strange warmths of wood and light, staircases that seem to curve without instruction. It is a bureaucratic structure, but it dreams. And somehow, the city allows it.\n
	There is no clear reason for this permission. The building is too large for its surroundings and too quiet for its size. It does not welcome, yet it does not repel. People enter it for music and theatre, but they leave with the sense that something else is being rehearsed behind the walls. The lights are carefully controlled. The acoustics are perfect. It behaves itself. But beneath the concrete skin, something thoughtful is moving, and no one has asked it to stop.",
				"sound_path": ""

			}
		},
		"connected_zones": ["National War Memorial", "National Arts Centre – Interior"],
		"characters": []
	},

	"National Arts Centre – Interior": {
		"zone_name": "NationalArtsCentreInterior",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The interior is quieter than expected, even when full. Sound moves strangely here. Footsteps are softened, voices do not echo. The light is amber and indirect, filtered through layers of intention that no one remembers authoring. The ceiling folds in repeating geometries that suggest order but offer no comfort. The stairs rise slowly, not as an invitation, but as a condition. It is not dark, but it is never bright. The shadows feel installed. Hallways extend in directions that seem deliberate but unmarked. Doors remain closed longer than they should. Somewhere nearby, music is being tuned, but you will not hear it until the building is ready.\n
	This is not only a theatre. It is a space made entirely of in-betweens. Every room feels like the threshold to another room that may not exist. There is no single place to rest your attention. You move through it with the sense that someone else is waiting for your arrival, though they have not called you forward. There is no enchantment here. Only precision, and the feeling that it has been allowed to go too far.",
				"sound_path": ""

			}
		},
		"connected_zones": ["National Arts Centre" , "National Arts Centre – Spectacle Room"],
		"characters": []
	},

	"National Arts Centre – Spectacle Room": {
		"zone_name": "SpectacleRoom",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Shh, the show will start soon.",
				"sound_path": ""

			}
		},
		"connected_zones": ["National Arts Centre – Interior"],
		"characters": []
	},


# ---------- Lyon Street Zone ----------
	"Lyon Street - Downtown": {
		"zone_name": "Lyon Street",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Lyon street is lined with fresh high rise condominiums and businesses, all creating thick shadows over the street. Here at night, things are far more subdued, but it's clear that this is a hub of activity when daylight strikes.

That's not to say that it's bereft of nightlife. A couple bars are open at this hour, not to mention the thumping of bass from a club down the way. People meander down the road, all looking to spice up their nightlives, and a few cars cut shapes through the road itself.

It's inviting in its strange, sleepy way. Perhaps you should explore; see what the night on Lyon Street has to offer.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Ottawa Downtown", "The Crimson Pulse","Blue Note Jazz Club"],
		"characters": []
	},

# ---------- Blue Note Jazz Club Zone ----------
	"Blue Note Jazz Club": {
		"zone_name": "Blue Note Jazz Club",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A dimly lit jazz club facade at twilight, its weathered brick walls soaked in cobalt shadows from adjacent alleyways. Neon letters spelling 'BLUE NOTE' buzz erratically above the entrance, casting crimson ripples across rain-slicked pavement where discarded trumpet cases lean against overflowing trash bins. Steel fire escapes coil snakelike up the building's flank.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Lyon Street - Downtown"],
		"characters": []
	},

# ---------- The Crimson Pulse Zone ----------
	"The Crimson Pulse": {
		"zone_name": "The Crimson Pulse",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The Crimson Pulse is settled in Downtown Ottawa, its scarlet neon sign is simple, yet flourished. Seemingly once an art deco theatre, now the black marble facade and smoked glass hide what await within, only the thumping of bass in your chest preparing you for what may lie within. Fervorous mortals line the sidewalk, appearing ready to claw each other apart for the chance at getting past the red-suited bouncers guarding the velvet rope. Getting past them for Kindred, though? Easy. You just steps up and they let you past, despite the protests of the kine in line.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Ottawa Downtown", "The Crimson Pulse - Main Floor"],
		"characters": []
	},

# ---------- The Crimson Pulse - Main Floor Zone ----------
	"The Crimson Pulse - Main Floor": {
		"zone_name": "The Crimson Pulse - Main Floor",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Inside is.. a lot, to say the least. The first thing one notices are the heavy scents of sweat, smoke, and perfume paired with the crimson strobe lights that bounce off of large shattered pieces of mirror hanging at various heights. It's a fever dream of industrial, goth, and techno beats while the facsimile of an anatomically-accurate heart hangs in lieu of a disco ball, pulsing with faint magenta light to the beat of whatever's playing. On one end of the space is a large stage that wraps in a crescent shape, currently occupied by barely dressed men and women twisting and writhing to the music in what appears to be interpretive dance.

Speaking of the crowd: it's an interesting mix here. Club kids, goths, and models make up the majority here, but there seem to be some more adrenal types: junkies and thrill-seekers posted up near the bar. The staff here are all pale and eerily calm, always smiling pleasantly and eager to please as people make their requests. Except at the velveted curtains on either side of said bar. Occasionally, you can glimpse the mirrored stairs behind them, leading up to assumedly the wrought-iron railed balcony that edges this entire experience. The mystery of what is behind the smoky curtains above just tantalizingly close. Yet.. almost every person that tries to go up is turned away. Though, a very select few have been ushered past. And you? The red-suited bouncer just gives you a single glance before stepping aside and allowing you up above, should you be so inclined.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Crimson Pulse", "The Crimson Pulse - Upper Level"],
		"characters": []
	},

# ---------- The Crimson Pulse - Upper Level Zone ----------
	"The Crimson Pulse - Upper Level": {
		"zone_name": "The Crimson Pulse - Upper Level",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The outermost ring of the balcony has various open lush leather booths, everything lit extraordinarily dimly with pale red light. In many places, however, these break off into velvet-curtained private rooms, some of which are open with silk-lined couches visible within. Each one is permeated with soft incense that seems to warp your own senses, dulling them the longer you're exposed, but not to a point of detriment for you. To a mortal, though? They'd probably be completely lost in it. It's dark, dangerous luxury: if you wanted to meet someone important or feed on one of the flock below, this somehow felt perfectly right for both in equal measure.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Crimson Pulse - Main Floor", "Private Room One", "Private Room Two"],
		"characters": []
	},

# ---------- "Private Room One" Zone ----------
	"Private Room One": {
		"zone_name": "Private Room One",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A dimly lit room cordoned off by a red velvet curtain. Inside is a lush silk-lined couch that circles the space and leaves a large opening in the center. Incense burns in here, seemingly entering through the vent, that dulls the senses, though not enough to be a detriment. At least, not for Kindred.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Crimson Pulse - Upper Level"],
		"characters": []
	},

# ---------- "Private Room Two" Zone ----------
	"Private Room Two": {
		"zone_name": "Private Room Two",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A dimly lit room cordoned off by a red velvet curtain. Inside is a lush silk-lined couch that circles the space and leaves a large opening in the center. Incense burns in here, seemingly entering through the vent, that dulls the senses, though not enough to be a detriment. At least, not for Kindred.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Crimson Pulse - Upper Level"],
		"characters": []
	},

# ---------- Crimson Pulse - The Antechamber Zone ----------
	"Crimson Pulse - The Antechamber": {
		"zone_name": "Crimson Pulse - The Antechamber",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Down a hidden elevator in one of the private rooms, what lays below is the true heart of the Crimson Pulse. The walls here are polished concrete with mirrored columns and black lacquer furniture. Everything gleams down here with damp heat and too much perfume. The lighting is subtle and dim, led by crimson and amber strip lights in recessed groves in the walls. But it's just so much.. more. What scents above were down here exacerbated with the heavy stenches of opium and marijuana now permeating beneath the numbing undercurrent of perfumes.

Here in the antechamber, long black leather couches and low glass tables are scattered with half-empty syringes, gold-rimmed goblets, and small trays filled with the ashes of incense. There are several small rooms off of the sides in here, each with beds covered in dark silk sheets, distorting mirrors, and humming with a strangely trance-like frequency. These? Probably meant to steal a moment for feeding. Or whatever else strikes the patrons' fancies.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Private Room One", "Crimson Pulse - The Core"],
		"characters": [],
		"secret_entry_passwords": ["duval"],
		"accessible_from_zones": ["Private Room One"]
	},

# ---------- Crimson Pulse - The Core Zone ----------
	"Crimson Pulse - The Core": {
		"zone_name": "Crimson Pulse - The Core",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Where the Antechamber gave an appetizer, here is the main course. In the center of the room is a wide circular bed with black silk sheets, overhung by translucent fabric that gives the illusion of smoke. All along the walls of this room are couches, kept pristine despite the mess of the previous area, and always occupied by one or two pale figures locked in an embrace -- or more.

Behind the bed is a single, large, antique mirror. Its surface is black as oil. Just the presence of it raises the hairs on the back of your neck in animalistic discomfort. In front of it is a table with a figurine of a coiled serpent around a large red pillar candle.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Crimson Pulse - The Antechamber"],
		"characters": []
	},


############# CENTRETOWN ##########################

"Centretown": {
	"zone_name": "Centretown",
	"default_viewpoint": "main",
	"category":"ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Centretown is where Ottawa pretends to be real. Glass offices and civic banners declare relevance, but the ground underneath is soft with erasure. Every building has had five names. Every plaque contradicts the last. The streets are wide and gridded like a failed utopia, but their corners still fold in on themselves, pooling with sirens and shredded pamphlets. Somewhere under Metcalfe, an escalator hums without a staircase. People hear it in their sleep.\n\nThis is where the city dreams in policy. You can feel it in the libraries, the union halls, the way rain seems to fall slower near Somerset. Fluorescent-lit diners flicker with the guilt of a thousand unkept appointments. Tenants change, landlords vanish, but the leases renew themselves. Something here wants you to fill out forms until you forget what you were proving. The lights stay on because someone, somewhere, is still counting.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Bank Street (Centretown)", "Sparks Street (Centretown)", "Ottawa Downtown", "Centretown West","Armory Drive", "The Glebe", "Golden Triangle", "Catherine Street (Centretown)"],
	"characters": []
},

# ---------- Armory Drive Zone ----------
	"Armory Drive": {
		"zone_name": "Armory Drive",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The avenue ran like a seam through the darkened fabric of the city. The low amber glow of the streetlights seemed less like illumination and more like a hesitant stain, unsure if it should fully commit to the dark. Storefronts along the block included the heavy stone facade of a hotel, a restaurant with condensation blurring its glass, and a store whose display window showed only shadow. They looked less like places of business and more like quiet, waiting faces.

Above them, power lines stretched and swayed, a tangled script written against the indifferent blackness. Everything felt held in a state of indefinite pause, even the heavy brick that should suggest permanence. The few cars that moved seemed to glide, their engines muffled, as if the air itself were too thick for sound. Traffic signals changed with a strange, lingering slowness, the shift from one color to the next a moment that stretched past its natural duration. The sidewalks held no footsteps, only a suggestion of recent movement, a chill that lingered in the space where people should have been.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Centretown", "The Armory Hotel"],
		"characters": []
	},

# ---------- The Armory Hotel Zone ----------
	"The Armory Hotel": {
		"zone_name": "The Armory Hotel",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The double doors of The Armory Hotel closed with a pneumatic sigh, sealing off the street's humid silence. The lobby opened up, a deep, rectangular space that felt too grand for its actual size. The air hung still and cool, a temperature that suggested disuse rather than comfortable climate control. Overhead, the chandeliers, heavy brass and clouded glass, cast a light that seemed to merely acknowledge the corners of the room, rather than truly illuminate them. Their glow picked out the textured wallpaper, a faded tapestry of pattern, and the dark wood paneling that climbed halfway up the walls, giving the room a sense of being perpetually submerged.

The reception desk, a fortress of polished oak, stood empty. Its pigeonholes, meant to hold keys, were vacant, each dark square a tiny, unblinking eye. A brass clock above it marked time with an oppressive stillness; its soft ticking was a sound almost imagined, like a memory of a sound. In the sitting area, deep red velvet armchairs and a matching sofa sat arranged around a low table, their cushions plump and undisturbed. They looked less like furniture meant for guests and more like an exhibit, waiting patiently for a pose that would never come. The quiet was thick here, a presence that settled over everything, pushing against the ears, making one aware of the sudden, startling beat of one's own heart.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Armory Drive"],
		"characters": []
	},
	
	# ---------- The Sanctuary - Parlor Zone ----------
	"The Sanctuary - Parlor": {
		"zone_name": "The Sanctuary - Parlor",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "You've come a long way. Take a seat :)",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Armory Hotel","The Sanctuary - Bedroom","The Sanctuary - Study"],
		"characters": [],
		"secret_entry_passwords": ["youreinvited"],
		"accessible_from_zones": ["The Armory Hotel"]
	},
# ---------- The Sanctuary - Study Zone ----------
	"The Sanctuary - Study": {
		"zone_name": "The Sanctuary - Study",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "You've come a long way. Take a seat :)",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Sanctuary - Parlor"],
		"characters": []
	},

# ---------- The Sanctuary - Bedroom Zone ----------
	"The Sanctuary - Bedroom": {
		"zone_name": "The Sanctuary - Bedroom",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "You've come a long way. Take a seat :)",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Sanctuary - Study"],
		"characters": []
	},

# ---------- Room 307 Zone ----------
	"Room 307": {
		"zone_name": "Room 307",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The heavy door to the room eased open, revealing a space that felt both formally appointed and subtly lived-in. The air hung cool, but not sterile, carrying a faint, pleasant scent of old paper and something metallic, like polished brass. The floral patterns on the curtains and the bedspread, rich with deep greens and muted reds, were clearly the hotel's choice, a flourish that was functional, if not quite personal.

To the right, the double bed, a grand affair of dark wood and plump pillows, looked invitingly soft, as if waiting to absorb one's weariness. And then, to the left, the desk. Upon it there is a laptop; a sturdy, pale grey machine sat open, its screen a dark mirror. Beside it, a book lay splayed open, spine broken from frequent reading—a treatise on physics, perhaps, or advanced technology given the glimpse of diagrams on the visible page. Nearby, a small stack of other volumes, some thick with academic heft, others worn with the casualness of a well-loved paperback: physics, more technology, and a collection on comparative religion. A comfortable armchair, upholstered in deep crimson, was tucked neatly beneath the desk, as though its occupant had only just risen. The closet door, slightly ajar, revealed a quiet regiment of dark clothing, hinting at a wardrobe of both practicalities and a touch of formality. This wasn't merely a hotel room; it was a quiet, temporary world, carefully arranged, and bearing the clear imprint of someone fully at ease in their own company.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Armory Hotel"],
		"characters": [],
		"secret_entry_passwords": ["Gnosis"],
		"accessible_from_zones": ["The Armory Hotel"]
	},

"Bank Street (Centretown)": {
	"zone_name": "Bank Street (Centretown)",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Bank Street stretches through Centretown like a bulging, flickering. It is too wide to feel old, too narrow to feel new. Lampposts flicker in the afternoon like they are unsure they should be on yet. The storefronts try their best: diners from the 1950s, mini-marts from last week, a bank that looks like it was born tired. Above, utility lines sag like exhausted syntax, trailing down the corridor in tangled punctuation. Everything feels temporary, even the buildings that have been here since Diefenbaker. Cars idle under red lights that seem to last longer than memory. On weekends, the sidewalks fill with people pretending they are not from here. Behind them, office towers from the downtown core loom like supervisors on break. This is Centretown’s pulse, but the rhythm is syncopated. It is too slow for ambition, too fast for comfort.",
			"sound_path": ""

		}
	},
	"connected_zones": ["The Afterlife – Entrance", "Centretown"],
	"characters": []
},


"The Afterlife – Entrance": {
	"zone_name": "The Afterlife – Entrance",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "Sat on Bank Street, The Afterlife is a hub of activity for the alternative and punk scenes of the city, hosting new, up-and-coming underground bands each night and even the occasional big name. At it's double doors, 2 bouncers stand - One checking the IDs of those waiting in a small queue along the front of the building, the other stands with a clipboard with a list of pre-approved regulars and guests who can skip the line and monitoring the smoking area outside the building.",
			"sound_path": ""
		}
	},
	"connected_zones": ["The Afterlife", "Bank Street (Centretown)"],
	"characters": []
},



"The Afterlife": {
	"zone_name": "The Afterlife",
	"default_viewpoint": "Main",
	"category": "Club001",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "The ground floor of The Afterlife pulses with gritty energy; neon-soaked walls, industrial metal accents, and a stage where underground and up-and-coming bands showcase their talents, surrounded by a crowd clad in leather, spikes, and avant-garde fashion. Above it stands a mezzanine that seems more quiet, likely a private area, overlooking the chaos below through wrought iron railings and smoked glass panels. At the far end of the room stands a door with a guard posted outside it — clearly some sort of VIP or employee-only area.",
			"sound_path": ""
		}
	},
	"connected_zones": ["The Afterlife – Entrance"],
	"characters": []
},

"The Afterlife – VIP": {
	"zone_name": "The Afterlife – VIP",
	"default_viewpoint": "Main",
	"category": "Club001",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "Through the backdoor leads a staircase to the VIP basement. Walking through the stairwell, the sound and chaos of the club above dies down somewhat, though can still be heard through the brick and concrete. The VIP area is significantly more expensive than the club above; smooth comfortable leather booths — all with ample room to sit, even for the largest of Kindred — and dimly lit chandeliers contrast the industrial metal accents and exposed brickwork. Across the far wall is a private bar, tended by the same bartender each night.",
			"sound_path": ""
		}
	},
	"connected_zones": ["The Afterlife"],
	"characters": [],
	"secret_entry_passwords": ["ChipIn"],
	"accessible_from_zones": ["The Afterlife"]
},
# ---------- Afterlife Apartment - Main Room Zone ----------
	"Afterlife Apartment - Main Room": {
		"zone_name": "Afterlife Apartment - Main Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The space is simple; unfinished. There's a main living room here with an attached kitchen and a small hallway. The living room is furnished only with a dark blue couch and a coffee table. The kitchen? There's some varioius colored bottles in the fridge and often a couple on the counters, but there isn't a single dish in sight.

Going down the hallway, there are four doors: a bathroom, a bedroom, a locked office, and a second exit out to an alley beside the club.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Afterlife - VIP", "The Afterlife - Entrance", "Afterlife Apartment - Bedroom", "Afterlife Apartment - Office"],
		"characters": [],
		"secret_entry_passwords": ["goldbottle"],
		"accessible_from_zones": ["The Afterlife - VIP", "The Afterlife - Entrance"]
	},

# ---------- "Afterlife Apartment - Bedroom" Zone ----------
	"Afterlife Apartment - Bedroom": {
		"zone_name": "Afterlife Apartment - Bedroom",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A sparse bedroom with a gray-sheeted queen bed, a nightstand, and a wooden dresser. The lamp on the nightstand is often left on and the shadows in here seem longer than they should be. A few picture frames are on the table along with a selection of books both old and new.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Afterlife Apartment - Main Room"],
		"characters": []
	},

# ---------- "Afterlife Apartment - Office" Zone ----------
	"Afterlife Apartment - Office": {
		"zone_name": "Afterlife Apartment - Office",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The office is dominated by a single wooden desk with a computer on one side, surrounded by stacks on stacks of old journals and books. On the opposite side of the room are a multitude of cardboard boxes and wooden crates, all stamped with various destinations from all around the world.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Afterlife Apartment - Main Room"],
		"characters": []
	},


"Sparks Street (Centretown)": {
	"zone_name": "Sparks Street",
	"default_viewpoint": "main",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Once a main street in Centretown, Sparks Street was converted to a pedestrian-only area some 20 years ago in an effort to improve commerce. Initial success brought in new businesses alongside some of the city’s oldest and most important structures, creating a clash of eras and aesthetics that survived even as that initial success faded. Now, it’s an ideal tourist destination, featuring food, nightlife and the arts right alongside historical landmarks.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Nourrir", "Centretown", "Christ Church Cathedral"],
	"characters": []
},

# ---------- Christ Church Cathedral Zone ----------
	"Christ Church Cathedral": {
		"zone_name": "Christ Church Cathedral",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The hallowed building stands tall but not proud as the crown jewel of a faith from times long past but not forgotten. Christ Church Cathedral takes as much of its name from the Lord's Son as its presence does on the surrounding secular buildings.

The matted brick walls, maculated by the occasional darker stone, bleed their details like a flagellant's back. Two identical scarlet blood doors invite believers and visitors alike to step inside, may their consciousness withstand of the Lord's gaze.

The bell tower stands by its side, a high guardian taking watch as it chants of the unrelenting flow of time; its tolls reminding all those around that one day it will in fact be their last.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Sparks Street (Centretown)", "Christ Church Cathedral - Nave"],
		"characters": []
	},
	
	# ---------- Christ Church Cathedral - Nave Zone ----------
	"Christ Church Cathedral - Nave": {
		"zone_name": "Christ Church Cathedral - Nave",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The smell of incense hits the nostrils with a faint feeling of remeniscence and solemnity, hanging around all those that step inside like mist. The hallowed silence of the nave weighs down on those that enter without purpose or a clear conscience, violated only by whispered prayers and the occasional cough.

Marble statues form a scattered crowd that stands by quietly, watching with judgement in their unblinking eyes, instilling the fear one's thoughts might spill into the outside and break the silence. The far-reaching ceiling stretches above to vertiginous heights, adorned with icons too far away to be concerned with those standing below, its faded colors blending into the stained glass and the motley shadow cast below.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Christ Church Cathedral"],
		"characters": []
	},
	
	# ---------- Christ Church Cathedral - Crypt Zone ----------
	"Christ Church Cathedral - Crypt": {
		"zone_name": "Christ Church Cathedral - Crypt",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Behind an impossibly thick reinforced wooden door lays what very well appears at first glance to be an old crypt, decorated with various knickknacks and furniture that strip the place of its cold appearance and in its place leaves a somewhat out of place homely feeling.

The chiselled stone walls bend above, hunched forward as they blend with the stubby columns into the vaulted ceiling. Several thin chains run along the walls, the column and back, criss-crossing above as several small crosses, pendants of peculiar making and shiny pad locks hang from them akin to make-shift decorations.

The air hangs warmer than one would expect from such a place, both figuratively and literally. The clash between the coldness of the stone structure and the warmth of the interior in the form of all the objects and ornaments scattered around is palpable, which - despite its original purpose - makes it so the place carries a most evident feeling of cozyness and of being lived in.",
				"sound_path": ""
			},
			"Close Up": {
				"image_path": "",

				"description": "A cursory glance around notes how most of the surfaces appear to be cluttered with various objects and knickknacks, almost leaving them no respite amidst the crowd. Metal and marble figurines are surrounded by a multitude of crystals, geodes and points that - despite their scattered appearance - seem to instead be placed with purpose at a further glance.

A cluttered table lays in one of the corners. A moderate stack of paper - both clean and not - occupies its surface beside scattered art supplies. The results from such chaos hang just above and all around in the form of several drawings, most of them portraits and simple landscapes of average talent.

Around a corner lays a simple tub, its very presence raising the question of what exactly was the initial purpose of the place or what kind of extensive renovations had it been through. Not to mention the questionable placement of it, given the very open space nature of the place. ",
				"sound_path": ""
			},
		},
		"connected_zones": ["Christ Church Cathedral - Nave", "Christ Church Cathedral"],
		"characters": [],
		"secret_entry_passwords": ["sweetsacrifice"],
		"accessible_from_zones": ["Christ Church Cathedral - Nave", "Christ Church Cathedral"]
	},

"Nourrir": {
	"zone_name": "Nourrir",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "By all appearances, the restaurant Nourrir fits in with the rather expensive, tourist-centric area where it's located, with trendy neon signage over a faux-vintage storefront of carved wood and colorful glass. Inside, it's all dark wood and velvet under low lighting. Walls without windows are decorated with a variety of impressionist paintings, including cards with the artists' statements. Plush seats surround the tables, which are each filled with sparkling glassware and, if someone is eating, a rotating collection of plates featuring a variety of small and intricate dishes. The jazz music is soft but ever-present and may be provided by a live band on special nights. From the main dining area, kitchen doors are visible as is the entrance to a room reserved for special events.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Sparks Street (Centretown)"],
	"characters": []
},
	
"Nourrir - Private Dining Room": {
	"zone_name": "Nourrir - Private Dining Room",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "Nourrir's private dining room looks much like the rest of the restaurant, but is a smaller space with one larger table. It has a separate entrance to the kitchen, keeping it completely separated from the public dining room so long as the doors are closed.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Nourrir"],
	"characters": [],
	"secret_entry_passwords": ["le sang"],
	"accessible_from_zones": ["Nourrir"]
},
# ---------- Catherine Street (Centretown) Zone ----------
	"Catherine Street (Centretown)": {
		"zone_name": "Catherine Street (Centretown)",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Catherine Street runs east to west at the south end of downtown Ottawa, providing access to the Queensway and ? as a result ? is typically filled with a steady flow of traffic.

The person for whom it was named, Catherine K. Stewart, has quietly faded into history. Little is known about her, other than the fact that she was the wife of lumber baron William Stewart and the mother of their six children.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Centretown", "The School of Dance"],
		"characters": []
	},
	
# ---------- The School of Dance Zone ----------
	"The School of Dance": {
		"zone_name": "The School of Dance",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The School of Dance is Ottawa's pinnacle of artistic virtue, which unwavering standards of excellence set the stage for it to grow into the world class arts education institution it is today. 

Founded in 1978, The School's Mandate is to operate exclusively as a charitable organization for the sole purpose of promoting education in the art of dance in Canada. with a mission to instil a love of the arts by offering and ensuring accessibility to the highest standard of dance training programmes and recreational programmes to all members of the community whether their interests be professional, leisure oriented or purely recreational.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Catherine Street (Centretown)", "The School of Dance: Entrance Hall"],
		"characters": []
	},

# ---------- The School of Dance: Entrance Hall Zone ----------
	"The School of Dance: Entrance Hall": {
		"zone_name": "The School of Dance: Entrance Hall",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The main hall of the dance school stretches before you like a long breath held in stillness, its arched ceiling curving overhead with solemn grace. The air feels still and cool, carrying the faint scent of dust and old polish, mingling with the ghost of rosin and sweat. Every step you take echoes gently, blending with the low hum of the lamps above.

Standing there, you can almost hear the faint rustle of satin slippers and the rhythmic tap of shoes that once filled the space. Now, only silence remains, rich and tangible, pressed between the stone walls. The light glows faintly on framed notices and wooden doors, and for a moment, the corridor feels both timeless and expectant, like a stage waiting for the first dancer to appear.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The School of Dance", "The School of Dance: Practice Room"],
		"characters": []
	},

# ---------- The School of Dance: Practice Room Zone ----------
	"The School of Dance: Practice Room": {
		"zone_name": "The School of Dance: Practice Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The air inside the practice room feels cool and faintly metallic, carrying the quiet hum of still electricity from the overhead lights. The walls, painted in shades of gray and blue, seem to press inward slightly, their surfaces heavy with silence. Light spills softly across the black dance floor, glinting on its polished surface like thin sheets of ice. The mirrors along one wall reflect the empty space endlessly, bending the light in subtle distortions that make it hard to tell where the room truly ends. Each reflection flickers faintly with a golden hue from the line of bulbs above, casting a warmth that canft quite chase away the chill.

At the far end the piano rests in shadow, its lacquered body absorbing the light, its silent keys like teeth waiting to be touched. Every small movement echoes, a shift of breath, a scuff of a shoe, and fades too quickly, swallowed by the roomfs stillness. It feels like stepping into a memory, or the aftermath of something beautiful, where the absence of sound becomes its own kind of music.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The School of Dance: Entrance Hall"],
		"characters": []
	},


############################################################################

########### DALHOUSIE CENTERTOWN WEST #######################################

	"Centretown West": {
		"zone_name": "CentretownWest",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": true,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Centretown West is a district of layered tenancy and slow erosion. The houses were not built to last, but they have. Their endurance is not deliberate, only the result of habit and weather. Walls bow outward from pressure no one speaks of. Gardens take root in paint buckets. Wires cross the sky in tangled lines. The wind moves unevenly here and turns corners it should not know.\n
	The people do not gather, but they remain. They cook quiet meals in narrow kitchens and speak in borrowed tongues. They pass one another like shadows exchanged between doorframes. Each address has belonged to someone else and will again. The neighborhood is not beautiful, but it is remembered. Not cherished, but fed.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Centretown West Northern Fringes", "Ottawa Downtown", "Centretown", "Lebreton Flats", "Little Italy", "Chinatown"],
		"characters": []
	},


"Centretown West Northern Fringes": {
	"zone_name": "OttawaCentretownWestFringe",
	"default_viewpoint": "main",
	"category": "ottawa_low_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "This is the northern fringe of Centretown West, where the city forgets to sweep and the streets lose their names. The tents cluster here, just before the land buckles into Lebreton Flats. Canvas, tarp, stolen signage, all stitched into shelter. Smoke drifts from garbage fires, curling between rusted poles and silent trees. The skyline is still visible, blurred by grime and weather, but it feels like another world. Nobody patrols this edge. Nobody counts the souls who sleep here. The stroller has no child, only plastic bags. The silence is broken by coughing, or the sound of a tin can being kicked out of the way. This is not poverty. It is the city’s discarded memory, gathered into makeshift homes before the emptiness swallows it whole.\n\nLebreton Flats begins just beyond those last sagging wires. The camp holds on like rot at the edge of a scar, too stubborn to die, too forgotten to matter. The people here do not look toward downtown. They look down, or not at all. Somewhere behind them, the street signs still say Ottawa, but it means nothing. The city ends here, not with a border but with a shrug.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Lebreton Flats", "Centretown West"],
	"characters": []
},
########################################################################

#################Lebreton Flats######################

"Lebreton Flats": {
	"zone_name": "Lebreton Flats",
	"default_viewpoint": "main",
	"category": "Creepy001",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Lebreton Flats is not a neighborhood. It is a refusal. The city cut it out like rot and never closed the wound. From Booth Street to the riverbank, there is only municipal silence. Broken pavement, dead grass, rusted lampposts that hum without light. After the demolitions of the 1960s, the Flats were promised rebirth. What came instead was entropy. Concrete bones protrude from the dirt like accusations. Chain-link fences sag where footpaths run between collapsed foundations. The homeless gather in the shell of a burned-out depot, lighting fires in cracked barrels. Some are mad. Some are sick. All are invisible. The air smells of wet insulation and mold. There is no rhythm here, no sirens, no footsteps. The land has turned against its owners.\n\nThe Flats do not belong to anyone. They are city land, yes, but only on paper. The police never come here. Not from fear, but because there is nothing to protect. It is a zone the city would rather not only ignore but see erased entirely. Bureaucrats speak of cultural renewal but forget the soil still remembers fire. Children are warned away from the fences, though few need the warning. The silence is enough. No residents. No voters. No use. And yet the place endures, like a secret waiting to be misremembered. Every year brings another proposal, another sketch for museums or parks or something that glows. The Flats reject it all. They have chosen stillness. Not because they failed, but because they were never meant to remain.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Centretown West Northern Fringes", "Centretown West", "Little Italy"],
	"characters": []
},

# ---------- Sacred Heart Shelter Zone ----------
	"Sacred Heart Shelter": {
		"zone_name": "Sacred Heart Shelter",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The shelter is nestled on the edge of Lebreton Flats, around the corner from the hospital. The buildings surrounding it are old and relatively run down, with the shelter itself being a repurposed clinic of some kind. The main room is a tidy dining hall lit up by bright fluorescent lights that flicker every now and then. A door behind the main counter leads to the kitchen, and a door to the side leads to the sleeping area where about 30 beds are arranged in neat rows. The walls and floors are clinically clean, but parts of the roof are unfinished, and small sections of the brick walls are damaged, revealing the pipes and insulation. It is recently renovated, but shows signs of age and neglect in every corner.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Lebreton Flats"],
		"characters": [],
		"secret_entry_passwords": ["Vital"],
		"accessible_from_zones": ["Lebreton Flats"]
	},


########## By-Rideau Ward ###################

########### LowerTown #####################

"Lowertown": {
	"zone_name": "Lowertown",
	"default_viewpoint": "Main",
	"category":"ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"Main": {
			"image_path": "",

			"description": "Lowertown breathes through its teeth. The streets are too narrow for comfort, too old for order, and too alive to be quiet. Stone and brick lean inward, holding the heat in summer and the cold in winter, never quite letting go. Church towers and corner stores share corners like cousins who do not speak anymore. The air smells like bread and incense and cigarettes. Some windows are open when they shouldn’t be. Others have been shut for years.\n
You feel it in the soles of your shoes. The slant of the sidewalk, the way light bends around the laundromat at dusk, the sound of a conversation continuing just after you’ve passed. Murals fade under layers of new paint. Bicycles rust in place. At a glance, it looks forgotten. But nothing is ever truly lost here. The neighborhood keeps everything. Every broken latch, every accent, every quiet song that spilled from a window in the middle of the night. It doesn’t ask who you are. It already knows.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Byward Market - Clarence Street", "Byward Market - Rideau Street", "Notre-Dame Cathedral Basilica", "Ottawa Downtown", "New Edinburgh", "Hull Downtown", "Sandy Hills"],
	"characters": []
},

# ---------- Notre-Dame Cathedral Basilica Zone ----------
	"Notre-Dame Cathedral Basilica": {
		"zone_name": "Notre-Dame Cathedral Basilica",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Standing among bustling streets and electric street lights, the Notre-Dame Cathedral is a shameless anachronism against the modern backdrop. A mixture of Neo-classical and Neo-gothic architecture, the exterior presents a humble facade of gray-white brick that hides the gleaming extravagance of the interior. The cathedral is the oldest standing church in Ottawa, one of the oldest buildings in fact, but the limestone walls and gleaming steeples have weathered the ages well. 

It is said that once, a humbler, wooden church sat on this spot- tending to the humbler souls of a humbler Ottawa. Then the city grew, with it grew the congregation, and so the little wooden church made way for a colossus of stone.
Recently, the grand structure has been labeled a historic site, leaving it more open to the public outside its typical flock.
And to you.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Lowertown", "Notre-Dame Cathedral Basilica Interior"],
		"characters": []
	},

# ---------- Notre-Dame Cathedral Basilica Interior Zone ----------
	"Notre-Dame Cathedral Basilica Interior": {
		"zone_name": "Notre-Dame Cathedral Basilica Interior",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The plain skin of the Cathedral gives way to its gleaming guts as you enter. Statues of saints and holy men stand amongst carved marble columns, stretching up to gleaming arches and a ceiling that glimmers in deep blues and twinkling golds to imitate a night sky that can’t be seen in busy Ottawa. During the day, the rays of the sun must cast this palace in radiance, but the electric streetlights faintly glowing through the stained glass makes for a pale imitation, leaving the icons and paintings cloaked in shadow.

Without its flock and shepherds, the church is more like a tomb than a place of worship, vast and quiet. Every footstep you take on the polished floors echoes like a gunshot amongst the empty pews, while French and Irish patron saints glower down at you silently from the many stained glass windows lining the walls.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Notre-Dame Cathedral Basilica"],
		"characters": []
	},

	"Byward Market - Rideau Street": {
		"zone_name": "RideauStreet",
		"default_viewpoint": "main",
		"category":"ottawa_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Rideau Street stretches across the city like a line someone drew too confidently and never corrected. It is wide, uneven, always active. The buses arrive in long chains, red-lit and patient, idling beside storefronts that never truly close. Pedestrians move quickly, heads down, as if following instructions no one remembers giving. The Rideau Centre pulses behind glass, humming with escalators and recycled air. Across from it, the Château Laurier watches without comment, heavy with windows and unbroken protocol. The pavement gleams at night whether it rained or not. Streetlights flicker in rhythm with nothing. Screens flash, signals change, but the city does not seem to progress. It circulates, loops, corrects. Rideau does not speak to you. It holds you in place until you understand how long it has been awake.",
				"sound_path": ""

			}
		},
		"connected_zones": ["McDonald's – 99 Rideau", "Lowertown", "The Electric Carousel"],
		"characters": []
	},
# ---------- The Electric Carousel Zone ----------
	"The Electric Carousel": {
		"zone_name": "The Electric Carousel",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "As soon as you push through the grimy door from the fast-paced street, time freezes.
The Electric Carousel Arcade beams its neon glow on the faces of the people dragging themselves on Rideau Street, a pulsing yet hidden shelter for nerds, misfits and lonely people. 

Inside, a thick fog of cigarette smoke permeates the place, giving it an eerie lighting with the pulsing colors from Galaga and Dragon's Lair. 
The air hums with 8-bit sounds, creating an hypnotizing melody, lulling the patrons alongside the stupor from the beer and the hashish they seek as they drop another quarter in search for the next high score.
The sound of tapping fingers echoes in the hall, where your feet sticks to days of stale drinks poured near the machines.
People come and go, reaching for the nearby McDonald's for a fast meal, losing quarter after quarter to beat the next dragon.
A coin drop, an asteroid explode. Rinse. Repeat. The perfect web.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Byward Market - Rideau Street"],
		"characters": []
	},
# ---------- The Carousel Backroom Zone ----------
	"The Carousel Backroom": {
		"zone_name": "The Carousel Backroom",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The 8-bit tunes outside fade into the low hum and stuttering whirr of modems as you step into the cramped room.
Dozens of CRT monitors bathe the walls in shifting greens and reds, and the floor is a chaotic spill of tractor-feed printouts strewn everywhere.

At the center stands a reclining chair, sagging and misshapen from years of use, while mismatched stools crowd around it in no particular order.

In one corner, a dirty bed lies bare, stripped of sheets.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Electric Carousel"],
		"characters": [],
		"secret_entry_passwords": ["galaga"],
		"accessible_from_zones": ["The Electric Carousel"]
	},


	"McDonald's – 99 Rideau": {
		"zone_name": "McDonalds99Rideau",
		"default_viewpoint": "main",
		"category":"ottawa_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The McDonald’s at 99 Rideau is a hole in the city’s mouth, always open, always swallowing. The lights flicker but never go out. The floor sticks. The bathrooms are locked or flooded or both. People don’t eat here so much as wait for something worse to happen. Dealers lean by the exit. Fights start over nothing. A man screams at the soda machine and wins. The air tastes like salt, bleach, and breath held too long. Security pretends not to see. Staff serve with eyes that do not blink. At three in the morning it feels like the only place still alive in Ottawa, and it should not be.",
				"sound_path": ""

			}
		},
		"connected_zones": ["McDonald's – 99 Rideau : Interior", "Byward Market - Rideau Street"],
		"characters": []
	},

	"McDonald's – 99 Rideau : Interior": {
		"zone_name": "McDonalds99RideauInterior",
		"default_viewpoint": "main",
		"category":"",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Inside, it feels like a punishment no one remembers handing down. The ceiling is too low, the lighting too loud, the heat uneven and sour. Tables wobble. Chairs are bolted down and still manage to move. The floor is wet for reasons no one explains. Conversations happen in mutters, in arguments, in languages you almost recognize. Someone is always sleeping with their head on the tray. Someone else is pacing the same tile over and over like it owes them money. The fryers scream in the back, but the food comes out cold. Security stands near the door and does not intervene. Everything smells like old ketchup and failure. You cannot tell how long you’ve been here, and by the time you leave, the building has taken something small from you. It never says what.",
				"sound_path": ""

			}
		},
		"connected_zones": ["McDonald's – 99 Rideau"],
		"characters": []
	},

	"Byward Market - Clarence Street": {
		"zone_name": "ClarenceStreet",
		"default_viewpoint": "main",
		"category":"ottawa_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "Clarence Street does not sleep so much as it pauses, waiting for someone to realize it never wanted to be a street. The lamps are too yellow, too dim, spaced just far enough apart to leave questions between them. Storefronts line the road like teeth after a long night, all signage faded, all doors closed but not locked. There is movement behind the glass, but only the kind you sense, never see. The pavement glistens without rain. A car is parked without a driver. The Parliament silhouette looms in the distance, indifferent and still. Everything here feels like the end of something that has not happened yet.",
				"sound_path": ""

			}
		},
		"connected_zones": ["ByWard Garage", "Lowertown"],
		"characters": []
	},

	"ByWard Garage": {
		"zone_name": "ByWardGarage",
		"default_viewpoint": "main",
		"category":"ottawa_high_outside",
		"is_neighborhood": false,
		"viewpoints": {
			"main": {
				"image_path": "",

				"description": "The ByWard garage crouches behind the market like it was put there to keep something in, not store anything. Its lights are too few and too dim, humming just enough to remind you they are failing. The concrete is warm in summer, sweating in winter, never fully dry. Cars come and go, but the place itself does not move. The signs point nowhere. The air smells like rubber, coin metal, and something faintly sweet, like fruit gone soft in the dark. You can walk through it without being stopped. No one will say anything. But the sound of your footsteps will follow you longer than they should.",
				"sound_path": ""

			}
		},
		"connected_zones": ["Byward Market - Clarence Street"],
		"characters": []
	},

"Byward Market - York Street": {
	"zone_name": "YorkStreet",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "York Street carries the bones of Bytown beneath its pavement. Once a line for timber carts and laborers, it still feels more like a passage than a place. The bricks on either side are survivors of the city’s early fires, their edges chipped and darkened, as if remembering smoke. The lamps do not brighten so much as mark territory, leaving wide shadows where silence gathers. The market shuts down, yet the air lingers with bruised fruit and stale beer, the kind of smell that does not wash out. Cars idle without drivers. Windows stare without light. The street waits, not for traffic, but for someone to notice how long it has been waiting.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Zaphod Beeblebrox Entrance", "Byward Market - Clarence Street", "Lowertown"],
	"characters": []
},

"Zaphod Beeblebrox Entrance": {
	"zone_name": "ZaphodBeeblebroxEntrance",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The doorway to Zaphod Beeblebrox pretends at starlight but never leaves Ottawa. Its sign hums in uneven blue against brickwork older than the club’s ideas, framed by green-painted pillars that lean like they were never measured. The glass door wears layers of tape and torn posters, fingerprints pressed so long they have become part of the pane. A locked service door beside it stays the same shade of moss every season. The sidewalk shows scars from utilities long since removed, square cuts that never healed. Steam crawls from the alley vents, curling into the sign’s glow. The place wants to be cosmic, but it feels more like a bar drafted into a ledger.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Zaphod Beeblebrox", "Byward Market - York Street"],
	"characters": []
},

"Zaphod Beeblebrox": {
	"zone_name": "ZaphodBeeblebrox",
	"default_viewpoint": "stage",
	"category": "Club001",
	"is_neighborhood": false,
	"viewpoints": {
		"stage": {
			"image_path": "",

			"description": "The stage at Zaphod Beeblebrox is not elevated. It just happens to be where the lights are pointed. Inspired by basement venues and B-side bootlegs, it is a shallow platform barely separated from the crowd, framed by cables that crawl across the ceiling like exposed nerves. The walls are black-painted cinderblock, chipped and recoated so many times they feel soft to the touch. A single fan turns overhead, not to cool the room but to keep the sweat moving. The audience is packed tight, shoulder to shoulder, their boots stuck to the floor and their faces lit in bursts of red and green. The sound doesn’t echo. It just stays.",
			"sound_path": ""

		},
		"bar": {
			"image_path": "",

			"description": "The bar at Zaphod Beeblebrox is a long stretch of scuffed wood that drinks as much as it serves. Its surface is carved with initials, ticket stubs pressed into its cracks, and rings left by glasses that never dried. Behind it, the shelves glow with cheap bottles lit from below, labels curling from the damp. The bartenders move fast but without ceremony, their motions rehearsed like factory work. The air is thick with the mix of stale hops, spilled spirits, and the tang of wet coats drying too slowly. Every stool wobbles. Every glass feels borrowed. The bar is less a place to rest than another part of the noise.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Zaphod Beeblebrox Entrance"],
	"characters": []
},


########################### New Edinburgh ##########################

"New Edinburgh": {
	"zone_name": "New Edinburgh",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Brick houses gather close along narrow streets, their walls darkened by damp and age, their windows glowing faintly like eyes that do not sleep. Beyond the fences, embassy gardens linger under trimmed hedges, but the air feels staged, too neat, too careful. The roar of the Rideau Falls seeps in from the edge of the neighborhood, constant and heavy, a sound that drowns out whatever else might be moving in the dark. Lamps stretch their light thin across the cobblestones, leaving more shadow than glow.\n\nThis is New Edinburgh, a corner of Ottawa where diplomacy and secrecy hardened into brick and iron. The streets do not invite, they observe. After sundown the silence sharpens, broken only by the water’s endless crash, a reminder that the city’s veins end here in noise and mist. It is less a place to live than a precinct of vigilance, a neighborhood that remembers its purpose and does not let you forget it.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Lowertown", "Lindenlea", "Rockcliffe Park"],
	"characters": []
},

######################### Rockcliffe Park Zone ########################
	"Rockcliffe Park": {
		"zone_name": "Rockcliffe Park",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Nestled against the south bank of the river, this small village on the outskirts of Ottawa is the kind of quiet only old money can afford. Opulent manors nestle upon large, well manicured lawns, silently passing judgement over the vagabond trespassers who dare to walk these dark streets past sundown. The narrow, winding roads are carved through dense patches of trees and around empty parks, no sidewalks that might invite a curious outsider in for a stroll. Despite the beauty of the buildings and surrounding nature, the palace gives off a clannish hostility: You do not belong here.



The neighborhood playing at town owes its name to the acres of carefully preserved woodland that surround this bastion of the aristocracy, a buffer against the encroaching press of humanity in the city proper. Blue-collar crime is all but none existent here, yet still every other home is surrounded by a wrought iron fence or hedge row to protect against the greedy ambitions of downtrodden masses who will never even lay eyes on the welcome mat. Self-made prisons that trap their prisoners in a bubble of privilege and the paranoia that comes with having what the have-nots don’t.",
				"sound_path": ""
			},
		},
		"connected_zones": ["New Edinburgh", "Lindenlea"],
		"characters": []
	},

# ---------- Thorne Manor Zone ----------
	"Thorne Manor": {
		"zone_name": "Thorne Manor",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Among the ancient buildings of Rockcliffe stands the Thorne Estate, looming proud and imperious over the banks of the Ottawa river. The building itself is massive- two stories tall, with a three door garage and attached conservatory. This old, Tudor-style manor has weathered the years well, though it is starting to show signs of its age. Approaching the entrance, the faded brickwork is crumbling in places, cracked paint chips from the sturdy wooden doors, and the roaring lion knockers are corroded from gold to an off-green.

Still, the venerable structure has seen recent renovations. The wrought iron fence that surrounds the manor is free of rust or foliage, sturdy bars have been installed over the windows, and carefully tended rose bushes twist about the foundation like beautiful yet wicked barbed wire. What's more, modern security cameras keep careful watch over the house, their red eyes blinking as they dutifully monitor the yard and drive leading up like electronic gargoyles. Whoever lives there now, they’ve turned the place into a veritable fortress.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Rockcliffe Park", "Thorne Manor Main Hall", "Thorne Manor Bath House", "Thorne Manor Ballroom", "Thorne Manor Conservatory"],
		"characters": [],
		"secret_entry_passwords": ["100 Diana Parkway"],
		"accessible_from_zones": ["Rockcliffe Park"]
	},
	# ---------- Thorne Manor Main Hall Zone ----------
	"Thorne Manor Main Hall": {
		"zone_name": "Thorne Manor Main Hall",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Upon first entering, visitors to the manor are first greeted by a grand staircase leading up to the second floor, the landing up above looming overhead. The large foyer is lavishly decorated, pictures of stately nobles line the walls, reproductions of plate armor stand eternal vigil, and an elaborate chandelier hangs high above the room, gleaming with electric lights that were no doubt added later. A fireplace sits cold to the side, likely unused since electric heating was added to the building.
The foyer connects to two halls, one on the first floor, and one on the second.
The first floor leads to the ballroom, kitchen, dining room, sitting room, billiards room, conservatory, library, bath house, and a door that leads down to the basement. A small bathroom with sink and toilet can be found here, too.
The second floor leads to the bedrooms, and has a narrow stairway leading to a small attic. Two full bathrooms can be found at either end of the hall, and a hatch for a dumbwaiter leads down into the kitchen.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor", "Thorne Manor Kitchen", "Thorne Manor Library", "Thorne Manor Bath House", "Thorne Manor Dining Room", "Thorne Manor Sitting Room", "Thorne Manor Billiards Room", "Manor Basement", "Thorne Manor Ballroom", "Thorne Manor Conservatory", "Thorne Manor Guest Room", "Rowan’s Room", "Juno’s Room", "Maximillian’s Room", "Thorne Manor Attic", "Oliver’s Room", "Jarro's Room"],
		"characters": []
	},

# ---------- Thorne Manor Kitchen Zone ----------
	"Thorne Manor Kitchen": {
		"zone_name": "Thorne Manor Kitchen",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "At first glance, the manor’s kitchen looks almost like it hasn’t changed since the building’s construction, though closer inspection reveals that the old gas fixtures have been replaced by electrical alternatives. The pantry is stocked with a humble collection of non-perishables and dry goods, but certainly not enough food to feed a large household. Rather, the food supply can be found inside the refrigerator: a collection of labelled blood bags, with blood type, humor, and a short donor description written on each.
The kitchen is small for the house’s size, but still large enough to prepare food for a sizable gathering should the need arise.

A door leads out into the main hall, and another into the dining room. In the corner, a heavy trap door almost blends in with the tiles, and when opened leads down a narrow stair into the wine cellar. A dumbwaiter leads up to the second floor of the house, sturdy enough to carry the weight of a small person if they don’t mind the cramped confines.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall", "Thorne Manor Dining Room", "Thorne Manor Wine Cellar"],
		"characters": []
	},

# ---------- Thorne Manor Library Zone ----------
	"Thorne Manor Library": {
		"zone_name": "Thorne Manor Library",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Hundreds of leatherbound tomes line the dusty shelves of this room, and none are simply for show- on inspection, each book is real and unique from the rest, no blank prop books or duplicates to pad out the shelves. There are volumes of all kinds, classic works of romance share space with horror, while historic records sit side by side with the complete works of long-dead philosophers, and many more topics besides. There are books on the occult, but if one goes looking for thaumaturgical prowess among these pages they will be sorely disappointed.

A couch offers readers a place to lounge, across from which a large writing desk is stacked with books and papers, and the manor’s only public phone. A fireplace sits against one wall, probably unused for decades, save as a place for the grand portrait of the manor’s original owner to hang. Tucked away in one corner, a small desk has been set aside for a Macintosh LC computer. The computer has a catalog of the library’s contents on it, and connects to the many security cameras keeping watch over the estate.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Thorne Manor Bath House Zone ----------
	"Thorne Manor Bath House": {
		"zone_name": "Thorne Manor Bath House",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The room you enter is one of extravagance, a decorative tile floor has been meticulously cared for and polished to a shine, tall, decorative stained glass windows line the farthest wall. The images depict prominent moments in kindred history, and the glass is also well cared for- near spotless apart from snaking ivy that creeps along the wall like a botanical frame for each window.

In the center of the room, extending to two of the chamber's walls, sits a large pool, it's waters run continuously through what seems to be some sort of filtration system- the spout of which takes the form of a man-made waterfall where the pool meets the edge of the room. It appears to be a communal bath of sorts, an indoor spring, with waters steaming and various oils and soaps lined around the rim of the pool in colorful and intricate bottles.

The chamber is supported by a smattering of ornate pillars, standing watch over the pool and providing some unseen divider between the spring and a rest area, decorated by comfortable seats and small tables for convenience.

At the very zenith of the chamber sits a large skylight, moonlight filtering in and reflecting off the waters, bathing the dim room in a calm, evening serenity. Here you feel welcome to rest, relax, and melt your worries away, a sanctuary closed off from the rest of the world... If only for the moment...",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall", "Thorne Manor"],
		"characters": []
	},

# ---------- Thorne Manor Dining Room Zone ----------
	"Thorne Manor Dining Room": {
		"zone_name": "Thorne Manor Dining Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "At the center of the manor’s dining room, a large mahogany table is set with enough space to comfortably accommodate a gathering of roughly twelve people. Silver candelabras and matching tableware are laid out, while crystal glasses and bone china dinnerware are found in a cabinet in the corner of the room. Two large windows look out over the well manicured garden, though thick curtains are often drawn over them. 

A large oil painting hangs on the far wall, looming over the head of the table. The painting is old, probably older than the house itself, and depicts the goddess Artemis and her hounds on the hunt, pursuing some unseen quarry beneath the full moon. Based on the style the painting must be from the mid 1700’s, but strangely it seems to depict the goddess less as an object of beauty or femininity, but as a powerful, dominant figure- the leader of the pack. Perhaps the roses that decorate the painting’s bottom edges hint at the true nature of the piece’s creator.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall", "Thorne Manor Kitchen"],
		"characters": []
	},

# ---------- Thorne Manor Sitting Room Zone ----------
	"Thorne Manor Sitting Room": {
		"zone_name": "Thorne Manor Sitting Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Just off the side of the main entrance, this well-decorated room is furnished with two large, antique leather couches, and several additional chairs to lounge in. A fireplace sits flush with the interior wall, and a large television is set up on the other side. Amongst the various decorations and knick knacks lining the walls and trophy cases, a few stand out as genuinely interesting pieces. Against one wall stands an elaborate suit of 17th century plate armor which, unlike the more decorative pieces found in the main hall, looks quite real; labeled with a small plaque on the base of the stand as, “Armor of Adelard the Dragonslayer.” Hanging from another, a massive wolf skill is mounted like a trophy piece, only labeled, “Hoia Baciu Forest, 1866.” And sitting in a trophy cabinet among many other esoteric objects, an unsettling fetish statue of shiny black metal depicts a leering figure with shark-like teeth, Chakravanti symbolism etched into its plinth.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Thorne Manor Billiards Room Zone ----------
	"Thorne Manor Billiards Room": {
		"zone_name": "Thorne Manor Billiards Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "This room is dominated by a large antique pool table in the middle, set up with balls and cues ever ready for the next game. A fully stocked bar is set up with stools and space for a bartender, a shelf of various liquors, mixers, and cigars behind it. A few leather armchairs are positioned in the corners of the room, ash trays available for those who choose to smoke. The room is filled with the stale scent of tobacco, the ghost of thousands of cigars infused into the very walls.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Thorne Manor Basement Zone ----------
	"Thorne Manor Basement": {
		"zone_name": "Thorne Manor Basement",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The basement has obviously gone through recent renovations, no trace of the original room remains. A vast room of concrete and cinderblock, interspaced with support pillars that keep the house above from collapsing in on the room below. Several smaller rooms branch off from the main space, mostly for utility and storage. A few errant boxes, tools, and a dirty mattress can be found stacked about here and there, but the basement is surprisingly empty. Hidden behind some plywood planks in the boiler room, an observant eye might find a hatch leading into the wine cellar.

Despite how empty the room is, it certainly has seen some use. A TV has been set up on a crate alongside a Nintendo Entertainment System with a small collection of games, some beanbag chairs set up in front of it.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall", "Thorne Manor Wine Cellar"],
		"characters": []
	},

# ---------- Thorne Manor Ballroom Zone ----------
	"Thorne Manor Ballroom": {
		"zone_name": "Thorne Manor Ballroom",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A large, empty room near the back of the estate, offering plenty of space for activities and gatherings. Large glass doors lead out onto a veranda overlooking the Ottawa river. Several sets of double doors lead into this room from the main hall, each are of sturdy construction, locking on the hall-side to secure the rest of the building from entry.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall", "Thorne Manor"],
		"characters": []
	},

# ---------- Thorne Manor Conservatory Zone ----------
	"Thorne Manor Conservatory": {
		"zone_name": "Thorne Manor Conservatory",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A dense forest of verdant plants grow beneath the glass roof and electric lightbulbs of the conservatory, with tangled vines creeping up the walls, elegant flowers blooming in hefty pots, and carefully labeled herbs plotted out in long planters. A staggering variety of greenery exists here, almost enough to get lost in, though even with the overwhelming diversity it’s obvious some are not quite natural. Strange, blood red fruits sit heavy on thorny vines, and wicked-toothed trap jaws await unwary insects… or perhaps larger prey.

The room is filled with the steady burbling of a large Victorian style fish tank that sits centered amidst the foliage. The elaborate iron-framed behemoth is more a fountain than a habitat, but nevertheless small shimmering shapes or silver and gold flitter through its green-tinged waters. Off to one side a table has been set up as a workstation, equipped with all sorts of gardening tools, as well as a spigot and hose to help with watering.

A glass door leads out into the garden, and a much sturdier wooden one leads back into the house.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall", "Thorne Manor"],
		"characters": []
	},

# ---------- Thorne Manor Guest Room Zone ----------
	"Thorne Manor Guest Room": {
		"zone_name": "Thorne Manor Guest Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A spare bedroom has been set aside on the second floor for guests of the manor. It’s a relatively small room equipped with a bed, dresser, and vanity for anyone staying the night to make use of. The dresser contains spare sheets and plenty of room for one to store their own things, and one of the night stands has a pencil and small notebook inside, otherwise the room lacks any other amenities.

One window would look out into the garden below, but a plywood board has been drilled into the wall to cover it, and even when removed, sturdy iron bars on the outside would prevent anyone from leaving out that way. Without a bathroom of its own, a guest would rely on the communal bathroom found down the hall.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Thorne Manor Attic Zone ----------
	"Thorne Manor Attic": {
		"zone_name": "Thorne Manor Attic",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The narrow stairs at the end of the hell lead up to a relatively small attic space, cleared out for living quarters rather than the storage room it once was. The first few pieces of furniture immediately obvious upon entry was an old desk, a standing mirror, and bed. The desk would feel like out of a study, though time has marred its mahogany surface, with few knicks and jagged edges leaving it in its current state of disrepair. The chair that accompanied it wasn’t in much better condition, with pieces of duct tape helping keep it together and a pillow to cushion the seat. The mirror was placed in the corner straight ahead of the door, giving a view onto the bed and vice versa. It was dusty, and the bronze frame had begun to take a polished complexion from repeated handling. The bed seemed to be in the worst state. The mattress was almost completely deflated, the texture raggedy and worn out, and certain spots of it seemed to have been sewn back together. The frame was metallic, looking like it fit more in a prison cell than in the manor it currently was set up in. Parts of it appeared to be rusty. In opposition to the rest of the bed, a simple and relatively well-maintained pillow and blanket were lain out on top.

To the right of the door was an old but unworn shelf, hosting several books, cassette tapes belonging to various bands if not blank, and other seemingly random decorations. Lining parts of the back wall, above the bed, were several posters and photographs, faded images of nature from a former life taking up the vast majority of photos. A singular, dim light was all that illuminated the room from the middle, held up by a single chain. The only other potential entry or exit was a window to the side of the desk, boarded up and with a curtain so as to prevent the sun’s deadly gaze from entering.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Oliver’s Room Zone ----------
	"Oliver’s Room": {
		"zone_name": "Oliver’s Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The Tremere’s room is covered with the laborious results of his research. A hefty writing desk is up against one wall, stacked high with papers covered in latin and aramaic scribblings, while his walls are covered with diagrams of exotic plants and arcane patterns. A bookshelf houses ancient tomes of blood sorcery and occult theory, as well as some more modern works on a variety of historic and anthropological studies. 
The room is furnished with a large bed, though it is just as often made into a makeshift work station, covered with yet more papers and notebooks when the desk simply isn’t enough space. A hefty trunk contains Oliver’s clothes and personal effects, as though ready to leave at a moment’s notice- or perhaps he’s simply too lazy to fully move in. A well used leather arm chair sits in one corner of the room, and a small yet heavy safe is pushed up against one side of the desk, securely locked to protect whatever the Tremere must consider valuable. 

There is one window in the room that would look out over the river, but it has been completely boarded up from the inside.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Thorne Manor Wine Cellar Zone ----------
	"Thorne Manor Wine Cellar": {
		"zone_name": "Thorne Manor Wine Cellar",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A flickering electric bulb struggles admirably to illuminate this cold, cramped room, shining dim light over the cool stone walls. Crumbling wooden shelves are stocked with hundreds of dusty old wine bottles, while casks full of forgotten vintages are labelled and organized along the walls.

One rack looks better taken care of, and is stocked with far newer bottles. One reads, 'Linda A. Harris, AB-, Sanguine. 29 years old, recent medical school graduate, well-balanced temperament. Harvested 10/21/1989.'
All the bottles on this shelf are labelled similarly.

Hidden near the back corner of the room, behind a few errant barrels, a small hatch leads into the manor’s basement.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Kitchen", "Thorne Manor Basement"],
		"characters": []
	},

# ---------- Juno's Room Zone ----------
	"Juno's Room": {
		"zone_name": "Juno's Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The room is made of tile, a meticulously clean, pristine white. A split in the wall was where the lighting poured from, illuminating the entirety in that same blinding shade. Wires rest along the floor, haphazardly strewn about, some connected to the computer in the corner, others connected to other bits of machinery here and there.. It was like a lab, almost. Overall the dwelling is clinical, sterile to a point, and very strictly cared for. There’s a simple bed pressed against the center of the back wall.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Maximillian’s Room Zone ----------
	"Maximillian’s Room": {
		"zone_name": "Maximillian’s Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The master bedroom looked more like an office than a place where anyone would sleep. An oaken desk, decorated with files and paperwork sits next to a large window, giving a view to the pond in the backyard. The walls were lined with bookcases, filled with old tomes, office supplies, and organized folders. The only indications that this was once the master bedroom is a small bed, tucked away in the back corner behind large blackout curtains, and the connected bathroom.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Jarro’s Room Zone ----------
	"Jarro’s Room": {
		"zone_name": "Jarro’s Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A modest door along the edge of the hall leads into Jarro's abode. The room is cluttered by all sorts of esoteric furnishings. Strange and abstract paintings line the walls, seemingly hung to make efficient use of the space rather than out of any sense of esthetics. Potted plants dangle from the ceiling and sit on shelves along the wall, adding a modest touch of green to the decor. 
A couch and a few chairs pull up alongside an armoire, each piece of furniture wildly different in style from the others, adding to the overall vibrant clash of visuals in the room. A simple bed is nestled in the corner, and at the foot of it dangles a large punching bag, held aloft by a thick chain. The bag is torn and ripped, with two more replacements leaning against the wall only a few feet away.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Cary's Room Zone ----------
	"Cary's Room": {
		"zone_name": "Cary's Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "More than anything, Cary’s room is full of memorabilia, of his own life and those similar. From the corny (souvenir mugs from across the States) to the personal (photos of him and friends in college and afterward), it’s all arranged nicely enough, but without much effort. The main goal here seems to be storage, as well as a place to rest, with just the most basic of personal comfort. This is not the room of someone who intends to spend a lot of time in their room. A large bed, comfortable armchair, desk and bookshelf make for the main furniture. 



A few items may be of note: a record player which Cary has playing pretty much any time he’s there and not in daysleep, accompanied by a truly insane collection of records. A motorcycle helmet he seems to have forgone ever wearing. A surprising number of books, mostly English literature alongside some history and social commentary.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},

# ---------- Rowan's Room Zone ----------
	"Rowan's Room": {
		"zone_name": "Rowan's Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "In contrast to its usually strict inhabitant, the room itself seemed like an indulgence in indolent behavior. A Daryl Hall and John Oates poster would be stuck to the wall across from the queen-sized bed, tilted somewhat off-kilter as if the common resident didn’t place too much emphasis on its alignment. Clothes, books, and other accompaniments would be scattered haphazardly on chairs and stools, sticking out of drawers and seemingly abandoned though distinctly they would all be clean.

As would be typical for vampiric inhabitants, the lone window overhead of the bed itself would be more than just boarded up. It would be entirely sealed and veiled with multiple layers of cloth overtop. The lone showing of meticulousness in a place of barely-controlled disarray.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Thorne Manor Main Hall"],
		"characters": []
	},
	
################# Lindenlea ########################
"Lindenlea": {
	"zone_name": "Lindenlea",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Tucked north of Beechwood, the houses stand small but deliberate, with steep roofs and narrow porches pressed along winding streets. Trees grow thick overhead, their branches locking together until the lamps struggle to break through, leaving sidewalks in uneven pools of shadow. The air carries the smell of damp soil and stone, a weight that clings to basements and stairwells. At night the streets twist back on themselves, each corner sharper than it should be, each turn uncertain.\n\nLindenlea was born from the garden city dream, but the dream feels uneasy. The planned lanes curl inward, looping into patterns that trap as much as they guide, until the neighborhood feels like it is folding in on itself. Windows shut early, porches sit vacant, and the quiet lengthens into something more deliberate than rest. The design whispers order, yet the mood suggests surveillance, as though the very plan was drawn not to free its residents, but to keep them accounted for.",
			"sound_path": ""
		}
	},
	"connected_zones": ["New Edinburgh","Rockcliffe Park"],
	"characters": []
},

########################## Sandy Hill ###########################

"Sandy Hills": {
	"zone_name": "SandyHill",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "East of downtown the ground slopes, and the houses lean with it, brick shells marked by chipped plaster and stairways that groan under their own weight. Trees crowd overhead in broken lines, their branches weaving over lamps that stutter out halos of sickly yellow. The air tastes of chalk dust and wet wood, with a faint bitterness of plaster crumbling in the rain. Every few blocks an embassy crouches behind wrought iron, too quiet, while the gaps between them are filled by student houses where the laughter sounds manic even before it cuts off.\n\nSandy Hill is the city’s split personality left in plain sight. Old mansions crumble into rooming houses, embassies shine with empty windows, and the apartments cough up tenants who move in and out like a revolving cast. It is polite by day, but at night the silence takes a paranoid edge, heavy and unblinking. Footsteps echo longer than they should, doors slam without faces, and the street seems to double back on itself. The neighborhood does not feel lived in so much as haunted by Ottawa’s need to remember and forget at the same time.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Ottawa Downtown", "Lowertown", "Golden Triangle", "Overbrook", "Old Ottawa East"],
	"characters": []
},

##################### Overbrook #############################

"Overbrook": {
	"zone_name": "Overbrook",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The houses sit low to the ground, their siding patched in mismatched colors, roofs marked by stains that never washed out. Chain-link fences lean at odd angles, gates swinging loose on rusted hinges. The streets are cracked and uneven, pools of dirty water swallowing what little glow the lamps can give. Down by the river the air is sour with algae and rust, seeping into basements that already smell of mildew. Even at night the highway above never quiets, its roar pressing down like a weight.\n\nOverbrook carries the look of neglect, a neighborhood patched over just enough to keep moving but never enough to feel whole. Shops along Coventry shutter early, leaving only dim reflections in their glass. The alleys run tight and strewn with bottles, corners marked by graffiti that looks older than it is. The silence here is uneasy, the kind that makes you check behind you even when no one is near. It feels less like a place to live than a place the city left behind, waiting to see how long it will hold together.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Sandy Hills", "Forbes", "Industrial Park"],
	"characters": []
},

# ---------- Industrial Park Zone ----------
	"Industrial Park": {
		"zone_name": "Industrial Park",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Industrial zone found within eastern part of Ottawa, with small houses and industrial areas dominating this land. Locals say this is where all the young citizens of Ottawa end up working.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Overbrook", "Old Ottawa East"],
		"characters": []
	},

# ---------- Gunsmiths R Us Zone ----------
	"Gunsmiths R Us": {
		"zone_name": "Gunsmiths R Us",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Haven of Jean-Claude Chanticleer, his personal workshop hidden within Industrial Zone, where he does maintenance and repairs of everyone's orders. Filled to the brim with necessary resources and tools, he can make just about any weapon and repair just about any common gun.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Industrial Park"],
		"characters": [],
		"secret_entry_passwords": ["SkibidiGuns"],
		"accessible_from_zones": ["Industrial Park"]
	},
	
######################## Forbes ##########################

"Forbes": {
	"zone_name": "Forbes",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Tucked off St. Laurent, the streets of Forbes run short and uneven, a tangle of low houses and tired walk-ups pressed against the industrial yards. The asphalt is cracked and buckled, lined with ditches that stink of oil and rainwater. Streetlamps give off a pale orange haze that seems to fade before it hits the ground, leaving corners where the dark gathers thick. The air carries the sharp tang of metal, a reminder of the garages and warehouses that sit just past the houses, their lots littered with rusted scraps.\n\nForbes feels like the edge of something, a neighborhood that lives under the shadow of workyards and traffic. The homes are small, patched over, curtains drawn early. Stray dogs move between the fences, their shapes quick and silent, and the only sound after nightfall is the low hum of machinery that never really stops. It has the air of a place nobody chose, where people end up rather than arrive. Walk too long through its streets and it feels less like you are crossing a neighborhood and more like you are being pushed out of the city itself.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Overbrook"],
	"characters": []
},


################# Hull ##############################

"Hull Downtown": {
	"zone_name": "HullDowntown",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The towers in downtown Hull reflect each other like liars trading stories, all glass and repetition, their surfaces too clean to trust. Walkways stretch between buildings like veins no one remembers stitching, each step echoing against concrete that never fully dried. Inside, the offices hum with low voltage and bad intentions, paper shuffled just to prove someone is listening. Outside, the sidewalks curve around bars that never close, never brighten, their windows filmed with the breath of men who speak in smoke. Nothing here points north. The signs contradict each other, and the streets pretend they’re part of something bigger across the river. But the river does not believe them. And when the sun sets, the light does not fall. It gets pulled down, slowly, like a body sinking.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Wrightville", "Lowertown"],
	"characters": []
},

  "Wrightville": {
	"zone_name": "Wrightville",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
	  "main": {
		"image_path": "",

		"description": "Wrightville sits low against the river, crouched in its own reflection. Houses press together with the posture of people who have waited too long in line, their paint cracked, their porches slanted just enough to whisper about weight. Power lines cross overhead in loose grids that buzz in the rain. There are too many backyards here, and most no longer know who owns them. At night, televisions flicker through curtains and cast strange liturgies onto plastic siding. The silence is slow and adhesive, like syrup left on a counter. Even the wind sounds reluctant.",
		"sound_path": ""

	  }
	},
	"connected_zones": ["Gatineau Park", "Hull Downtown"],
	"characters": []
  },

  "Gatineau Park": {
	"zone_name": "GatineauPark",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
	  "main": {
		"image_path": "",

		"description": "Gatineau Park begins where the city forgets itself. The pavement gives way to gravel, then to quiet, then to something older. Trees rise in patient formations, spaced like columns in a forgotten temple, their bark etched by wind and the slow discipline of time. The trails don’t lead; they suggest. Lakes sit like held breath between hills that never quite relax. In the underbrush, everything moves like it has permission. The park is not wild, but it is not tamed either. It watches. It remembers. And in the stillness between footsteps, the dark feels deliberate.",
		"sound_path": ""

	  }
	},
	"connected_zones": ["Gatineau Parkway", "Wrightville"],
	"characters": []
  },

"Gatineau Parkway": {
	"zone_name": "Gatineau Parkway",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
	  "Main": {
		"image_path": "",

		"description": "Gatineau Parkway coils like a forgotten, frozen serpent through the heart of the park. Towering pines lean inward while the brooding cliffs gaze down like sentinels carved from sorrow at the trodden white path below. Snow weighs down the branches beside and above, making them bow to those souls who pass through this long path. Only the ambient heat of the asphalt and the dedication of the city's snowplows keeps it somewhat visible, lined by walls of discarded snow that could bury a man alive. Many paths branch off the sides, some drawn with the tracks of skis and others with the heavy dragging of snowshoes. The only thing stirring is the swirl of flakes in the biting air. Each step forward is another toward the maw of a hungering winter beast.",
		"sound_path": ""

	  }
	},
	"connected_zones": ["Gatineau Park", "Lusk Cave - Entrance", "Phillipe Lake Campground"],
	"characters": []
  },

  "Lusk Cave - Entrance": {
	"zone_name": "Lusk Cave - Entrance",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
	  "Main": {
		"image_path": "",

		"description": "At the end of a half-frozen stream, peeking just above the snowline, a dark abyss waits to swallow the next who stumbles into it. The damp cavern air drifts over the white banks with a ravenous bite, leaving trails of ice over the skin of any who approach. Just inside, the ice breaks open to allow the stream to run through, thin and starving in these winter months. Forced to crouch down to half a man's height, once inside you're forced shin-deep into icy water. Each step inside is slick and deadly as if the cave itself desired the blood of its delvers. From deeper in, the wind moans mournfully. Nothing here is at a peaceful rest.",
		"sound_path": ""

	  }
	},
	"connected_zones": ["Gatineau Parkway", "Lusk Cave - Main Chamber"],
	"characters": []
  },

  "Lusk Cave - Main Chamber": {
	"zone_name": "Lusk Cave - Main Chamber",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
	  "Main": {
		"image_path": "",

		"description": "Finally, you can stand upright without rock scraping flesh from your skull. Pitch darkness surrounds you, even the air seeming to hold its breath. Here, the cave has opened up into a large chamber with several ledges and smaller crevices branching off into other sections of the cavern. One path has the faintest scent of fresh air. The others? Musky and damp. Forgotten. Whatever ancient things were once here, nothing remains. And yet, you feel unwelcome. The stone here whispers of blood and violence. Of trespassing. The urge to turn back wells in your chest. A primal instinct of flight.",
		"sound_path": ""

	  }
	},
	"connected_zones": ["Lusk Cave - Entrance"],
	"characters": []
  },

  "Lusk Cave - Hidden Path": {
	"zone_name": "Lusk Cave - Hidden Path",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
	  "Main": {
		"image_path": "",

		"description": "Braving through the oppressive atmosphere of the cave, you press yourself through a narrow fissure near the stone floor. The ancient marble digs into your flesh while you move, inch by inch. Here, you're a sitting duck. You can hardly move. The walls compress so tightly around your chest that you're certain that kine would suffocate before they made it to.. wherever this goes. Yet still, you inch onward through this claustrophobic nightmare. Or do you turn back? You're free range for anything ahead or behind and the animal stench here is only growing stronger..",
		"sound_path": ""

	  }
	},
	"connected_zones": ["Sera's Hideaway", "Lusk Cave - Main Chamber"],
	"characters": [],
	"secret_entry_passwords": ["sinclair"],
	"accessible_from_zones": ["Lusk Cave - Main Chamber"]
  },


  "Sera's Hideaway": {
	"zone_name": "Sera's Hideaway",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
	  "Main": {
		"image_path": "",

		"description": "The suffocating passage winds, expands, and contracts before finally opening up into a reasonably large chamber. Pelts are strewn around the place, a few knives and a handgun have been haphazardly thrown in a corner. Beside the pelts is a well-polished recurve bow and a quiver of arrows as well as a stack of papers -- newspapers, it looks like, from the last five years. Some are the Ottawa Citizen. Others? The Boston Globe. The New York Times. Beyond that, very little personal effects seem to dot the space.\n\nHowever, the other side of the cavern tells a new tale. Here, the bones of animals and humans alike have begun to pile. Old blood flakes from even more ancient marble. Claw marks mar the wall. But not all of the bones sit forgotten. Some have been carved. Others pierced with cord and wrapped. Tools and jewelry both. No part of the prey left to waste. All of nature had its purpose.",
		"sound_path": ""

	  }
	},
	"connected_zones": ["Lusk Cave - Hidden Path"],
	"characters": []
  },

  "Phillipe Lake Campground": {
	"zone_name": "Phillipe Lake Campground",
	"default_viewpoint": "Main",
	"category": "",
	"is_neighborhood": false,
	"viewpoints": {
	  "Main": {
		"image_path": "",

		"description": "A biting winter wind howls through the dark campground by Phillipe Lake, where a few dying campfires flicker weakly against the cold. Mist coils through the frost-covered trees and clings to the shore, veiling the landscape in a ghostly hush. The lake lies black and motionless, a mirror to nothing, its surface exhaling silence like breath from the grave. Shadows stretch long and unnatural, cast by the firelight, as if something unseen watches from the treeline. Once a place of warmth and stories, the campground now feels suspended between worlds—where time forgets to move, and the dead may still wander.\n\nWho knows what might become of these souls beneath the heavy boughs of winter?",
		"sound_path": ""

	  }
	},
	"connected_zones": ["Gatineau Parkway"],
	"characters": []
  },


# ---------- Golden Triangle Zone ----------
"Golden Triangle": {
	"zone_name": "GoldenTriangle",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The Golden Triangle lies before you, a slender wedge of city hemmed by the silent glide of the Rideau Canal and the restless pulse of Elgin Street. By day, its streets are filled with the warm hum of cafés, boutiques, and murmuring crowds, but as dusk falls, the energy subtly shifts.\n\nElgin Street, the western edge, wears its modern bustle like a mask. Under its glow of neon signs and laughter lie whispered bargains, fleeting alliances, and the soft shadow of predators choosing their moment.\n\nTo the east, the Rideau Canal mirrors the sky, its surface reflecting the glow of lampposts and the hush of drifting leaf shadows. In winter, it transforms into a vast expanse of ice, a pale stage where breath crystallizes and echoes seem too loud, where the world’s largest skating rink becomes a frozen altar, gleaming in the moonlight.\n\nAt night the streets darken, lanterns flicker, and the architecture breathes stories the living have long forgotten. This is not just a neighborhood. It is a vein through the city, where history and hunger swirl together beneath polished surfaces.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Elgin Street (Golden Triangle)", "Centretown", "Sandy Hills","Château de Ahn Driveway"],
	"characters": []
},

# ---------- Elgin Street Zone ----------
"Elgin Street (Golden Triangle)": {
	"zone_name": "ElginStreetGoldenTriangle",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Elgin Street runs like a vein through the Golden Triangle, pulsing with the lifeblood of Ottawa’s nocturnal elite. By day, the avenue wears the mask of respectability. Polished storefronts, boutiques displaying their high society luxuries, and cafés that whisper with the idle chatter of the well kept. As the sun surrenders, the street shifts. The air thickens with music, smoke, and temptation, and the Golden Triangle bares its fangs.\n\nAt its heart stands Ember Moon, a rock nightclub whose crimson neon sign glows like a wound in the night. The bass reverberates through the pavement, a siren’s pulse that draws mortals and Kindred alike. Inside, shadows writhe in rhythm, sweat and desire mingling beneath the burn of stage lights. Ember Moon is more than a club. It is a crucible of hunger, where whispers of backroom dealings vanish beneath the thunder of guitars.\n\nScattered along the street, other clubs pulse in counterpoint. Velvet draped lounges for the decadent, electronic temples where the music blurs into something mechanical and near bestial. Between them, the cold facades of art galleries rise like sanctuaries to beauty, their walls hung with visions that speak more of obsession than genius. Toreador prowl these halls as priests at their altars, their courtly games dressed in the guise of curation.\n\nNot far from the glow of indulgence lie old libraries, their spines cracked and pages heavy with dust. A few Kindred favor these quiet sanctums, their pale fingers turning the parchment of forgotten truths while the city outside roars with noise. Above, the skyline bristles with ornate apartments, homes of Ottawa’s gilded aristocracy. Their balconies overlook Elgin like watchtowers, where society’s chosen sip their wine and pretend not to notice the shadows sliding beneath them.\n\nThe Golden Triangle is more than a neighborhood. It is a stage for contrasts. Elegance and decay. Indulgence and secrecy. The pulse of the living and the silence of the dead. To mortals, it is a district of culture and pleasure. To the Kindred, it is contested ground, a hunting preserve wrapped in the trappings of sophistication, where every gallery, every bar, every chandelier lit apartment conceals a predator’s smile.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Château de Ahn Driveway", "Golden Triangle"],
	"characters": []
},

# ---------- Château de Ahn Driveway Zone ----------
"Château de Ahn Driveway": {
	"zone_name": "Château de Ahn Driveway",
	"default_viewpoint": "main",
	"category": "ottawa_private_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Along Queen Elizabeth Drive is a lone driveway locked behind heavy gates of older times. The wrought iron gate creaks faintly as the wind stirs it, its intricate patterns blackened by age and neglect. The stone pillars that flank it bear the weight of centuries, their weathered surfaces veined with moss and shadow. Beyond lies a path strewn with fallen leaves, a carpet of autumnal reds and golds that whisper underfoot with every step.\n\nThe forest beyond the threshold is quiet, too quiet. The kind of silence that feels heavy and expectant, as though the trees themselves are holding their breath. The narrowing path vanishes into the embrace of ancient trunks, where the last light of dusk struggles to penetrate the canopy.\n\nThis gate is not merely an entrance. It is a boundary. To cross it is to leave the world of the living behind, to step willingly into the domain of the unseen. Whatever waits beyond does not welcome the uninvited, yet it calls to those attuned to the secrets of the night.",
			"sound_path": ""
		},
		"Château":{
			"image_path":"",

			"description":"Before you rises a monumental mansion, a relic of bygone centuries, its walls entwined with ivy and scarred by time itself. Rounded towers, capped with slate tiled spires, loom like grim sentinels against the sky, while the tall windows are dark mirrors that make it hard to shake the feeling of being watched. The façade blends opulent elegance with oppressive weight. Stone, ornament, and shadow. Half hidden stairways wind toward massive entrance portals that make even the bold hesitate before crossing the threshold. The garden, immaculately kept and yet eerily still, feels more like a stage set than a living place. The flowers are too perfect and the grass too even, as if arranged by an unseen hand. At night, mist often shrouds the estate, and the crunch of gravel along the paths echoes too loudly between the arcades. This is no ordinary house. It is a haven for the Undying. A refuge where ancient intrigues are woven and masks of humanity are carefully maintained. Behind the heavy doors, the whispers of centuries linger, and in every shadow, the gaze of an elder may lie in wait.",
			"sound_path": ""
		},
		"Allée":{
			"image_path":"",

			"description":"The allée forms a grand, linear promenade leading toward the main entrance, bordered by two rows of tall, evenly spaced trees. Their canopies interlock overhead, forming a living tunnel where moonlight filters through in long, shifting shafts. The gravel path is well-raked and maintained, giving off a soft crunch beneath every footstep. Even at night, the allée feels ceremonial — a grand introduction to the old estate’s cultivated dignity. Wrought-iron lanterns installed discreetly among the trunks glow with a faint amber hue, creating rhythmic pools of light along the path. It is a place where footsteps echo slightly too long, and where the air always feels a touch cooler than elsewhere on the grounds. This is the path visitors remember when they leave; its quiet majesty lingers, subtly shaping their impression of the château’s imposing grace.",
			"sound_path": ""
		},
		"Kennels":{
			"image_path":"",

			"description":"The kennels are a sturdy, elongated stone outbuilding originally built for aristocratic hunting hounds. Heavy wooden doors and iron-barred ventilation windows give the structure a pragmatic, almost military efficiency. Inside, the scent of straw and clean wood lingers; each stall has been carefully maintained, with fresh bedding and neatly arranged feed bins. The floors are sloped subtly toward drainage channels — a design choice that speaks to both hygiene and the estate’s original commitment to excellence. Though the kennels are mostly quiet, there is an ever-present sense of readiness about them. The tools and tack for grooming, feeding, and training are all kept in perfect order, as though the space expects activity at any moment. Any animals that live here tend to show remarkable discipline, though the building itself reveals nothing unnatural. It is simply a practical space — just one that seems to operate a little too smoothly.",
			"sound_path": ""
		},
		"Training Grounds":{
			"image_path":"",

			"description":"A flat, sanded field bordered by low stone walls serves as the château’s outdoor training grounds. Meant for a different purpose before, it now accommodates a wider array of activities. Straw training dummies and wooden sparring posts stand in organized rows. Simple racks hold practice weapons, kept shaded under a small awning where tools and equipment hang with careful order. The air here carries the scent of dust and old wood, and even at night the ground feels warm from the day’s stored heat. The training grounds hold a sense of discipline without aggression — a space built for honing ability rather than showcasing it. Even when not in use, the field retains a faint hum of past activity. It feels like a breathing pause between nature and purpose, ready to be claimed by whichever resident seeks practice or release.",
			"sound_path": ""
		},
		"Stone Sculptures":{
			"image_path":"",

			"description":"Scattered throughout the gardens are stone sculptures accumulated over decades, more than half of them crafted by the château’s former resident sculptor during his mortal years. These pieces capture an impressive breadth of technical skill: serene faces carved with delicate precision, draped figures whose folds seem to shift with the breeze, and bold experiments in form that reveal an artist pushing the limits of his medium. Time and weather have softened some of their edges, lending them a quiet dignity. Moss gathers along pedestals and settles into recessed patterns, blending the artworks into their natural surroundings as though the earth itself has slowly embraced them. The collection spans a spectrum of styles — from classical revival to early modern experimentation — yet it all feels cohesive, united by the vision of one devoted craftsman. Each sculpture stands exactly where it seems meant to be, arranged to complement sunlight, foliage, or the line of a garden path. At night, subtle illumination transforms them into silhouettes that watch over the lawns with contemplative stillness. Taken together, the sculptures form an open-air gallery that speaks to the sculptor’s evolving craft, a testament to a creative life that left its mark in stone long after the hands that shaped it were finished.",
			"sound_path": ""
		},
	},
	"connected_zones": ["Château de Ahn - Reception Hall", "Château de Ahn - Garden", "Golden Triangle", "Elgin Street (Golden Triangle)"],
	"characters": []
},

# ---------- Château de Ahn - Garden Zone ----------
"Château de Ahn - Garden": {
	"zone_name": "Château de Ahn - Garden",
	"default_viewpoint": "main",
	"category": "ottawa_private_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The garden unfolds like a carefully composed requiem. Orderly, elegant, and faintly unsettling in its perfection. The stone path winds with deliberate grace along the grounds, its pale surface whispering beneath each step. Overhead, wooden trellises form a vaulted canopy, from which lavender drapes in languid strands, the fragrance cloying in the night air. Sweet, with a suggestion of decay.\n\nLanterns hang from the beams, their glow subdued, casting long and skeletal shadows across the path. Their light is not warm, but pale and uncertain, illuminating only fragments of the way forward and leaving the rest to the velvet silence of the dark.\n\nFurther in the distance, a greenhouse rises, its glass panes gleaming faintly under the moonlight. Once a sanctuary for cultivation, it now serves as a secluded tea house. An oasis for clandestine meetings, whispered bargains, and conversations veiled in civility. Its walls of glass shimmer like the surface of a dream, offering the illusion of transparency while concealing truths far more dangerous.\n\nThis is no mere garden. It is a stage set for intrigue, where nature is tamed into elegance, and every detail reminds the visitor that beauty here is never without peril.",
			"sound_path": ""
		},
		"Tea House": {
			"image_path": "",

			"description": "The tea house stands like a glass cathedral in the garden, its iron frame overgrown with roses and ivy, illuminated by the glow of a crystal chandelier. Inside, the air is thick with the sweetness of blossoms, heavy and intoxicating, as though beauty itself were a trap.\n\nA long table dominates the space, set not only for tea but for whispered salons where Kindred weave intrigues as carefully as garlands. Velvet chairs, porcelain cups, and fragrant blooms create an atmosphere both divine and suffocating. Eden reimagined as a stage for politics and seduction.\n\nHere, elegance is weapon, and every gesture is calculated. The tea may be exquisite, but it is never what truly quenches the thirst of its masters.",
			"sound_path": ""
		},
		"Pool": {
			"image_path": "",

			"description": "The pool lies at the edge of the garden settled under a iron wrought glass ceiling that protects it from outside influences, bordered by pale stone tiles that hold the day’s warmth well into the night. Its water is impossibly clear, maintained with a noble estate’s sense of disciplined elegance. In the moonlight, the pool becomes a mirror; the still surface reflects the sky, the clipped hedges, and the carved balustrades of the château looming above it. The sound of soft breezes rippling across the surface adds a faint whisper to an otherwise serene environment. A row of wrought-iron lounges sits beneath stretched canvas awnings. The area feels meticulously maintained, as if someone takes personal pride in its appearance. Visitors often linger here not to swim, but to enjoy the illusion of calm it offers, a curated stillness that blends artifice with nature, and invites to a relaxing visit rather than activity.",
			"sound_path": ""
		},
		"Fish Pond": {
			"image_path": "",

			"description": "The fish pond stretches wide and calm, its perimeter marked by low stone lanterns imported from an earlier generation’s fascination with East Asian aesthetics. By day, koi drift lazily beneath drifting lily pads; by night, the pond becomes a dark basin broken by soft orange glimmers of the fish below. The air here smells faintly of water, wood, and the faint sweetness of plant life, creating a pocket of serenity within the more formal grounds of the estate. A small wooden pagoda stands to the side, constructed with craftsmanship meant to evoke peaceful retreat. Inside, a raised floor and open beams create a perfect vantage point to watch the pond’s stillness. The structure has become a favored place for quiet conversations and solitary nights, where the soft plinking of water and subdued rustle of reeds provide a natural rhythm for reflection. The ambiance is effortlessly calming, a counterpoint to the grandeur of the château proper.",
			"sound_path": ""
		},
		"Old Large Tree": {
			"image_path": "",

			"description": "On the far edge of the château grounds, a towering, ancient tree spreads. Its gnarled branches twist skyward like arthritic fingers, thick with the scars of centuries. The bark is rough and furrowed, darkened with age and streaked with lichen, each crack and knot a map of time’s passage. A faint, earthy scent clings to it, mingling with the moss that carpets its roots and the damp soil beneath. Moss creeps along its roots, clutching the earth like grasping fingers, and a faint, musty scent drifts from its shadowed base.

Despite its age, the tree feels alive with quiet power. Shadows pool beneath its wide canopy, and in the stillness, the rustle of leaves whispers like distant voices.",
			"sound_path": ""
		},
	},
	"connected_zones": ["Château de Ahn Driveway"],
	"characters": []
},

# ---------- Château de Ahn - Reception Hall Zone ----------
"Château de Ahn - Reception Hall": {
	"zone_name": "Château de Ahn - Reception Hall",
	"default_viewpoint": "main",
	"category": "ottawa_private_inside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The reception saloon serves as the château’s social threshold, where guests are welcomed before being granted deeper access. Softly upholstered furniture arranged in conversational clusters invites lingering, and the décor strikes a careful balance between intimacy and grandeur. A curated selection of paintings and objets d’art lines the walls, each piece chosen to reflect elegance without ostentation. A fireplace anchors the room with a gentle warmth, making it feel unexpectedly homelike. Evenings imbue the saloon with a quieter atmosphere. Lamps dimmed low and heavy drapery drawn closed lend the space a warm, cocoon-like quality. Conversations held here tend to feel more meaningful, shaped by the room’s understated dignity. Visitors often leave with the sense that they’ve been subtly evaluated — though nothing in the décor explicitly suggests it, the room feels like both a welcome and a test, a buffer between the outside world and the château’s deeper secrets.",
			"sound_path": ""
		},
		"Library": {
			"image_path": "",

			"description": "The library is a cathedral of silence, dressed in velvet shadows and fractured light. Tall, gothic windows spill a dim glow across the chamber, painting the air with the melancholy hues of dusk. Every shelf groans beneath the weight of ancient tomes, their cracked spines whispering of forbidden truths, their presence a promise and a warning alike.\n\nThe air is heavy with dust, wax, and faint traces of incense long burned out. Statues and carved columns watch like stone sentinels, their expressions unreadable in the flicker of lamplight. The ornate balcony above seems less a gallery for readers and more a vantage for unseen eyes.\n\nThe arrangement of furniture feels deliberate and almost ritualistic. Two opposing sofas like seats at a council of shadows, and a circular table at the center as if it were an altar to knowledge or power. Rich carpets dull every step, swallowing sound until even the smallest movement feels intrusive and sacrilegious.\n\nIt is a place for confidences and conspiracies, where the illusion of hospitality cannot mask the undertow of danger. Here, every book may be a weapon, every silence a trap, and every word the beginning of a pact sealed in blood.",
			"sound_path": ""
		},
		"Ballroom": {
			"image_path": "",

			"description": "Once designed for glittering soirées and orchestral performances, the ballroom remains the most grandiose chamber in the château. The polished floor gleams like a dark mirror under the light of crystal chandeliers suspended from frescoed ceilings. Tall windows draped in heavy velvet overlook the gardens, though they remain shuttered most nights. Columns and gilded moldings add vertical drama to the space, giving it a sense of airy opulence even when empty. Despite the lack of mortal festivities, the ballroom retains its echo of celebration. A faint trace of perfume, wax, and music seems to cling to the air, as though the room remembers its heyday vividly. Even in silence, the acoustics hold an anticipatory resonance, carrying the ghostly impression of shifting silk dresses and murmured conversations. Standing alone in the ballroom, one can feel the full weight of history — the centuries of indulgence, pride, and spectacle embedded in its walls.",
			"sound_path": ""
		},
		"Guest Rooms": {
			"image_path": "",

			"description": "The guest rooms reflect a more restrained version of the château’s aristocratic charm. Each chamber includes a four-poster bed or a plush modern equivalent, soft carpets or rugs underfoot, and a writing desk positioned near the window. The décor varies subtly between rooms — some lean toward classical minimalism, others echo Belle Époque softness — but all maintain a sense of refined comfort. Everything is perfectly maintained, giving the impression that guests could arrive at any moment. At night, the rooms feel peaceful in a way that is almost theatrical: curtains sway gently with drafts from old vents, wooden furniture settles with small creaks, and the distant hum of the château creates a calm but unmistakable presence. Guests find themselves lulled into a contemplative quiet, as though the space expects its occupants to rest deeply, even if few who stay here ever truly need sleep. The rooms welcome without insisting, offering hospitality without warmth — a careful balance that preserves the château’s dignity.",
			"sound_path": ""
		},
		"Interrogation Room": {
			"image_path": "",

			"description": "The interrogation room occupies a room deep within the château. Its stone walls are thick and cool to the touch, absorbing sound so effectively that the space feels unnaturally quiet even when empty. A single table with heavy metal chains and two chairs sit in the center beneath a stark ceiling lamp, casting long shadows that crawl across the uneven floor. The design is simple, stripped of any comfort or ornamentation, making the room’s purpose unmistakably functional. A faint scent of metal and cleaning agents lingers in the air, hinting at regular upkeep. The heavy door—reinforced far beyond what the original architecture required—closes with a resonant finality that reverberates in the chest. Visitors find the room unsettling not because of what is in it, but because of what is absent: warmth, softness, distraction. Everything is deliberate and focused, encouraging honesty through discomfort. It is not used often, but when it is, privacy is absolute, the kind that feels less like protection and more like isolation.",
			"sound_path": ""
		},
		"Vault": {
			"image_path": "",

			"description": "The château’s vault is a hybrid of old stone and modern reinforcement, concealed behind a door whose understated elegance belies its strength. Inside, the temperature is kept cool and constant to preserve precious documents, valuables, and long-held heirlooms. The shelves are meticulously arranged, with ledgers, cases, and sealed boxes stored according to a system that favors discretion over accessibility. Light comes from discreet fixtures that illuminate only what is necessary, keeping most of the vault in muted half-shadow. Despite its utilitarian purpose, the vault carries an unexpected sense of reverence. The echo of footsteps on stone feels amplified, and each object stored here seems to carry a story — some mundane, some weighty. Certain items appear to have been placed with more care than their monetary value would suggest, hinting at personal significance known only to the château’s residents. The vault protects not just wealth, but memory.",
			"sound_path": ""
		},
		"Training Room": {
			"image_path": "",

			"description": "The indoor training room provides a refined counterpart to the more rugged outdoor grounds. Wood-paneled walls and reinforced floors allow for both agility exercises and weapon practice, while racks of equipment line the edges in neat, utilitarian order. The lighting is steady and cool, illuminating practice mats, suspended bags, and a variety of training implements. Nothing in the room feels excessive—everything serves a purpose, every placement chosen for efficiency and clarity. The atmosphere is one of discipline, free from distraction. During the late hours, the training room acquires a different rhythm. The soft thud of strikes against padded surfaces echoes through the chamber, rhythmic and almost meditative. Occasional creaks from old beams punctuate the silence in a manner that feels oddly companionable. Practitioners often find themselves losing track of time here, absorbed in repetition and focus. The room does not judge, nor inspire bravado; it simply offers space to sharpen the mind through the body, even for those who technically no longer tire.",
			"sound_path": ""
		},
		"Jail": {
			"image_path": "",

			"description": "A narrow passage leads to a chamber stripped of dignity. The ice like walls gleam faintly, casting back a pale and pitiless light that spares nothing from view. There are no windows and no shadows to hide in. Only the raw, crystalline cold.\n\nInside, the barest elements of survival are laid out with clinical indifference. A cot thin as regret, a basin of stagnant water, and a toilet that reeks of utility. Nothing more. No softness and no comfort. Only existence prolonged until it is taken.\n\nThis is not a room, but a cage. A larder for the damned. The humans kept here are not chosen, but discarded by their own kind. Killers, predators, and wretches whose absence stirs no mourning. To the Kindred, they are nothing but vessels, blood held in skin, waiting for the kiss that will drain them dry.\n\nThe ice itself becomes a cruel irony. Beautiful, eternal, and utterly indifferent, it watches every moment of their captivity. In this place, humanity is reduced to stock, and death is not tragedy, but convenience.",
			"sound_path": ""
		},
	},
	"connected_zones": ["Château de Ahn - Coterie Meeting Room", "Château de Ahn Driveway"],
	"characters": []
},

# ---------- Château de Ahn - Coterie Meeting Room ----------
"Château de Ahn - Coterie Meeting Room": {
	"zone_name": "Château de Ahn - Coterie Meeting Room",
	"default_viewpoint": "main",
	"category": "ottawa_private_inside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "This chamber serves as the brain of the estate, where planning and deliberation take place. A polished round stone table sits at the center, surrounded by high-backed chairs that lend an air of solemnity to every discussion. Maps, documents, and instruments for charting territory or influence are stored in elegant cabinets along the walls. The lighting is subdued but focused, designed to encourage concentration without imposing harshness. It is a room where words matter, and silence carries weight. Thick curtains and deep soundproofing make the meeting room feel insulated from the rest of the château, creating a space where even heated arguments seem to occur in a vacuum. Something about the room compels formality; voices naturally lower, posture straightens, decisions become more deliberate. The atmosphere is not oppressive, but purposeful — a chamber shaped by the gravity of choices regularly made within its walls.",
			"sound_path": ""
		},
		"Study & Archive": {
			"image_path": "",

			"description": "The Study & Archive occupies a series of adjoining rooms designed for the dual purpose of thought and preservation. The study itself is a richly appointed space: carved bookcases, a heavy desk polished to a deep sheen, and a pair of armchairs arranged for conversation or quiet reading. Light pools in controlled, warm patches, illuminating papers, journals, and carefully ordered notes. The smell of ink and aged parchment blends with wax and wood polish, creating a cocoon of intellectual comfort. Even the ticking of a nearby clock seems slow and deliberate, as though the room rejects haste in all its forms. Beyond the study proper lies the archive — a cooler, narrower chamber where shelves stretch into the dimmer reaches of the room. Boxes labeled in tidy script, rolled maps tied with ribbon, and sealed folders are arranged according to a logic understood only by those who tend it. There is a sense of stillness here, a quiet authority held in the preserved history lining every wall. Some documents appear far older than the estate itself, though their relevance is left unspoken. Mortal or not, anyone entering the archive intuitively lowers their voice, respecting the gravity that permeates the space.",
			"sound_path": ""
		},
		"Photography Studio": {
			"image_path": "",

			"description": "Converted from a high-ceilinged service room, the photography studio balances modern equipment with the château’s architectural bones. Blackout curtains drape heavily from ceiling to floor, allowing total control of the lighting environment. Softboxes, tripods, and an assortment of lenses are arranged with meticulous care, while a folding table holds neatly organized film canisters and tools. The air has a faint chemical tang, softened by the warm hum of lamps and the neutral tones of the backdrop curtains. The space feels both creative and clinical — an atelier for images rather than paint. When the room is in use, it transforms completely. The interplay of light and shadow becomes its own language, crafting moods that range from serene to theatrical. Subjects stand perfectly still beneath the swells of illumination, their outlines captured in frozen moments that linger well beyond the click of the camera. Some photographs are clearly artistic studies, others more documentary, but all are treated with the same reverent precision. Once printed and hung to dry, the images seem to watch silently from their clips, granting the room an eerie sense of quiet observation.",
			"sound_path": ""
		},
		"Music Room": {
			"image_path": "",

			"description": "The music room occupies one of the château’s most acoustically resonant chambers. Thick carpets and discreet wall treatments soften excessive echo, allowing instruments to sing without distortion. A grand piano dominates the center of the room, its polished surface reflecting the glow of wall sconces. Nearby, stands for violin, cello, or wind instruments wait with poised elegance. The scent of rosin, aged wood, and polished brass hangs gently in the air, a comforting blend for anyone with a love of sound. The atmosphere encourages creativity without urgency, allowing melodies to unfold at their own pace. When played, the room transforms into a private concert hall. Notes bloom into the space with clarity, lingering in warm, golden reverberations that invite repetition and refinement. Even when unoccupied, the room retains a quiet expectancy—as though it remembers every piece ever played within its walls. Occasionally, someone wanders in during the late hours to coax a few solitary notes from the piano, filling the château with music that travels faintly through nearby corridors. The room respects these moments, holding them gently, waiting patiently for the next.",
			"sound_path": ""
		},
		"Atelier": {
			"image_path": "",

			"description": "The studio breathes with the silence of stone, a cathedral of dust and artistry where every chisel mark is both violence and devotion. Blocks of marble and limestone stand like mute sentinels in various stages of becoming. Some still crude and unshaped, others caught forever in the fragile moment between perfection and ruin.\n\nThe air is thick with the scent of powdered stone, mingling with faint traces of oil and wax. Shafts of pale light filter through high and narrow windows, illuminating the suspended haze like a holy veil, making every particle dance as if in reverence to the artist’s touch. Tools lie scattered across heavy oak tables. Chisels worn to familiarity, hammers balanced with surgical precision. Each instrument as much a weapon as it is a brushstroke.\n\nHalf finished statues linger in the corners. Faces too beautiful to be mortal, bodies sculpted with an intimacy that borders on obsession. Some smile in serenity, others twist in agony, yet all bear the mark of their creator’s hunger for beauty, meaning, and permanence in a world of decay.\n\nCandles burn low among the stones, their light caressing surfaces that seem to breathe in the dark. To step into this place is to feel the presence of its master even in absence. A Toreador who does not simply carve, but seduces the very marrow of the earth into immortal form.\n\nThis is not a workshop. It is a sanctuary, a shrine, and a mausoleum for the Toreador’s desires, where every echo of hammer against stone sounds like a heartbeat that should not exist.",
			"sound_path": ""
		},
		"Stone Vault": {
			"image_path": "",

			"description": "The chamber rests behind a sturdy wooden door, its frame scarred by years of quiet use. Within, the air is cool and clean, touched by the mineral breath of stone and the faint perfume of wood shavings. Pedestals and shelves line the space, carrying half shaped blocks, unfinished busts, and figures caught mid gesture, waiting for the sculptor’s hand to return. Some forms are rough outlines, others nearly complete, their silence heavy with potential rather than ruin. This is not a crypt, but a workshop paused in time. A sanctuary of intention where beauty lingers unfinished, each piece a promise still unfulfilled.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Château de Ahn - Reception Hall"],
	"characters": []
},

# ---------- Crystal Haven Zone ----------
"Arthur's Haven": {
	"zone_name": "Arthur's Haven",
	"default_viewpoint": "main",
	"category": "ottawa_private_inside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The haven opens like the heart of a gemstone split by divine hands. Walls shimmer with the fractured brilliance of sapphire crystal, each surface catching and bending the faintest light into a thousand shades of midnight blue. The air is cool, tinged with the mineral scent of stone, as though the room itself has been carved from the bones of the earth.\n\nLamps fashioned from crystal shards burn with subdued glow, their light refracted into glistening patterns that crawl along the walls like living veins of frost. Couches and tables are sculpted from the same glacial essence. The counters gleam with a predatory polish, their edges sharp as fangs, glowing faintly in the light.\n\nHere, time feels suspended. Every angle and every reflection is curated and orchestrated. The interplay of light and shadow becomes a living artwork that shifts with each flicker of the lamps. It is not merely a refuge, but a shrine to beauty itself, a Toreador’s cathedral carved from the secret heart of the earth.\n\nHere, surrounded by the illusion of eternal ice and cosmic silence, one can almost forget the heat of the hunt and the burden of eternity. Almost.",
			"sound_path": ""
		},
		"Bedroom": {
			"image_path": "",

			"description": "A side chamber opens from the crystalline lounge, its icy brilliance softened into something more personal. The walls still glimmer with the frozen light of the main hall, but the atmosphere here is warmer and more human. Less a shrine, more a retreat. The bed at the center of the room blends comfort with design, echoing the crystalline elegance around it. The frame is pale and smooth as sculpted frost, and it glimmers faintly in the ambient light.\n\nLarge enough for two, the bed is built for comfort above all else, a high quality resting place where true ease is valued more than display. Silk sheets shimmer in a shade reminiscent of a pristine lake, their blue so clear and luminous it feels as though one could see straight through to endless depths. Against the crystalline chamber, they blend seamlessly, echoing the serene clarity of water captured in eternal stillness.\n\nAround it, small details anchor the room in memory. Plush figures, carefully placed. Photographs of family, including a young boy with black hair and vivid blue eyes, his gaze bright with the vitality that faded after the Embrace. Collars from pets passed only a few years ago. A few books rest on a side table, their pages worn from reading yet cared for with gentle hands.\n\nAgainst one wall rests a statue of a small dog and cat entwined in an embrace, a masterwork of stone whose tender detail softens the ice and radiates a living warmth.\n\nThis room is not a gallery and not a performance. It is a sanctuary of memory. Fragile, private, sacred, and achingly human.",
			"sound_path": ""
		},
		"Red Room": {
			"image_path": "",

			"description": "Behind an unremarkable oak door in the east wing of the chateau lies a space of immaculate silence. The Red Room is sealed tight against the world, its soundproof walls swallowing breath, heartbeat, and confession alike. The décor is distinctly modern for 1990 — lush crimson velvet panels, recessed lighting softened by smoked glass, and the clean geometry of chrome and leather furniture. A discreet stereo system rests on a minimalist stand, capable of filling the air with the pulse of ambient sound. Every surface has been polished to a reflective sheen; the atmosphere feels less like decadence and more like discipline. Along the far wall stand several reinforced cabinets, their contents meticulously arranged. Each piece — forged steel, tempered glass, hand-stitched leather — has been crafted to endure. Nothing here is ornamental; every curve, every joint, every clasp is designed for absolute reliability under strain. The materials are chosen not for luxury, but for resilience — smooth where they must be gentle, unyielding where they must resist. It’s the perfection of the design that makes the room unsettling. The balance of beauty and function speaks of someone who treats endurance itself as art — who sees the threshold between pleasure and pain as a performance of will. To enter is to step into a gallery of tension, where craftsmanship and control have become indistinguishable. When the door closes, the Red Room becomes a world unto itself — silent, deliberate, eternal.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Château de Ahn - Reception Hall","Château de Ahn - Garden","Château de Ahn Driveway","Château de Ahn - Coterie Meeting Room"],
	"characters": [],
	"secret_entry_passwords": ["Crystal"],
	"accessible_from_zones": ["Château de Ahn - Reception Hall","Château de Ahn - Garden","Château de Ahn Driveway","Château de Ahn - Coterie Meeting Room"]
},

# ---------- Alistair's Room Zone ----------
"Alistair's Room": {
	"zone_name": "Alistair's Room",
	"default_viewpoint": "main",
	"category": "ottawa_private_inside",
	"is_neighborhood": false,
	"viewpoints": {
		"Bedroom": {
			"image_path": "",

			"description": "The room is composed in deep, comforting darkness—charcoal walls, muted wood tones, and the soft glow of a single warm lamp that never quite reaches the corners. A large bed dominates the space, its dark linens slightly rumpled, framed by sturdy nightstands that hold stacks of books and the occasional half-forgotten glass. A tall dresser and a closed wardrobe stand like quiet sentinels along one wall, their silhouettes softened by shadow. Opposite the bed, a modest desk sits beneath the low light, a laptop resting open as if waiting for its owner to return mid-thought. More books gather here—on the chair, under the desk, in an overburdened shelf nearby—creating an atmosphere of lived-in intellect. Despite the darkness, or perhaps because of it, the room feels calm, private, and unmistakably inhabited.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Château de Ahn - Reception Hall","Château de Ahn - Garden","Château de Ahn Driveway","Château de Ahn - Coterie Meeting Room"],
	"characters": [],
	"secret_entry_passwords": ["Deluge"],
	"accessible_from_zones": ["Château de Ahn - Reception Hall","Château de Ahn - Garden","Château de Ahn Driveway","Château de Ahn - Coterie Meeting Room"]
},

# ---------- Ember Moon Zone ----------
"Ember Moon": {
	"zone_name": "EmberMoon",
	"default_viewpoint": "main",
	"category": "ottawa_private_inside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The Ember Moon burns with 90s rock defiance, a neon crescent glowing blood red above its door. Inside, guitars scream, bodies writhe, and the air tastes of smoke, sweat, and hunger. Velvet draped booths cling to the edges of the chaos, where whispers of power and promises cut deeper than the music.\n\nAbove the bar, bottles glitter like stained glass in hellfire, every drink poured with a smile sharp enough to wound. Mortals think they have found rebellion, but the Kindred know better. The Ember Moon is their stage, their sanctuary, and their hunting ground.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Ember Moon - Outside"],
	"characters": []
},

# ---------- Ember Moon - Outside Zone ----------
"Ember Moon - Outside": {
	"zone_name": "EmberMoonOutside",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": false,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Outside, the Ember Moon radiates a dangerous allure. A cracked brick facade looms under the sickly glow of a towering blood red neon crescent, the light buzzing like a heartbeat in the night. The sign’s letters read EMBER MOON in defiant scarlet, throwing jagged reflections across rain slick pavement.\n\nThe alley leading to the entrance feels alive with shadow. Graffiti sprawls in chaotic color, cigarette smoke curls from clustered figures, and the low thrum of bass rattles the street like a pulse calling to the lost and the hungry. A rusted steel door, framed in velvet black drapes, is watched by a bouncer whose eyes linger too long, sharp enough to peel back the soul.\n\nFrom the outside, the Ember Moon glows like a secret whispered into the night. A promise of hidden pleasures and forbidden freedom, its neon fire luring the curious into its embrace.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Elgin Street (Golden Triangle)", "Ember Moon"],
	"characters": []
},


# ---------- Old Ottawa East Zone ----------
	"Old Ottawa East": {
		"zone_name": "Old Ottawa East",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Its spine, Main Street, curves like someone gave up on drawing it straight. Houses sit slightly askew. Drainage patterns make no sense. Sidewalks disappear, then reappear two blocks later. This is not a planned neighbourhood. It is a contradiction mapped in inches. Saint Paul University anchors the south end. Convenience stores outnumber caf s. A halfway house and a massage clinic share the same block. ",
				"sound_path": ""
			},
		},
		"connected_zones": ["Old Ottawa South", "The Glebe", "Sandy Hills", "Industrial Park"],
		"characters": []
	},



"Old Ottawa South": {
	"zone_name": "OldOttawaSouth",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Between the canal and the river, the streets knot themselves into Old Ottawa South, a strip that pretends to be cozy while something older breathes beneath it. Wooden porches lean over sidewalks that crack like broken teeth, and the lamps along Bank Street flicker over shops that feel more like holding cells than storefronts. The Mayfair Theatre glows in weak neon, its sign humming into the dark like a beacon for ghosts. The air clings heavy, a mix of damp brick and river silt that makes every corner taste stale.\n\nThis neighborhood is Ottawa’s conscience turned sour. It is the part of the city that remembers too much and hides it behind thrift stores, coffee counters, and long-standing pubs. The canal cuts one border, the river another, locking the streets into a pocket that has nowhere to go. After nightfall the silence has a pulse to it, steady and accusing, as though the houses themselves are keeping tally. Old Ottawa South is not about safety or tradition. It is about being watched, and about the city admitting, just here, that it never really trusted itself.",
			"sound_path": ""

		}
	},
	"connected_zones": ["The Glebe", "Carleton University Campus", "Billings Bridge", "Old Ottawa East"],
	"characters": []
},


"The Glebe": {
	"zone_name": "TheGlebe",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The neighborhood rests just south of downtown, wrapped tight against the canal like it was meant to be set apart. Its houses are old brick, wide porches and tall windows, built by families who wanted permanence and got it. Shops along Bank Street still bear their old bones under new paint, storefronts changing hands but never quite shaking the weight of history behind the glass. The trees along the avenues grow thick, their roots splitting the walks as though reminding the pavement which came first. In the daytime it looks like stability, but the quiet after dark feels closer to watchfulness than comfort.\n\nThe Glebe represents Ottawa’s craving for order dressed up as charm. It is the city’s mirror of middle-class certainty, where heritage and respectability sit on every corner, but that same polish hides a nervous edge. The canal marks it like a moat, a line drawn between itself and the city it claims to be above. To walk its streets at night is to feel that mask slip, the houses leaning too close, the silence pressing harder than it should. The neighborhood is not just old or settled; it is a reminder that Ottawa’s heart beats slow, steady, and always under someone else’s gaze.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Centretown", "Old Ottawa South", "Old Ottawa East"],
	"characters": []
},



"Billings Bridge": {
	"zone_name": "BillingsBridge",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Concrete hums at Billings Bridge, the weight of the span pressing into the river like a hand holding something down. The water churns black beneath it, catching faint scraps of light that break apart before they can form a reflection. Beside it the mall squats heavy, glass doors and tiled corridors that glow even after closing, a hive that refuses to sleep. The parking lots are wide and exposed, their painted lines stretching out like veins across empty ground.\n\nHere the city feels restless, as though it cannot sit still on its own foundations. The underpasses drip steadily, pools spreading across concrete that smells of iron and wet stone. Traffic shakes the span overhead, each passing car like a pulse too fast to be steady. Billings Bridge does not offer passage or arrival so much as pressure, the sense of being pinned between river and road, forced to listen as the current below whispers in a language you almost recognize.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Brookfield Gardens", "Old Ottawa South", "Faircrest Heights", "Applewood Acres"],
	"characters": []
},


"Brookfield Gardens": {
	"zone_name": "BrookfieldGardens",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Low apartment blocks line the bend near Heron Road, their brick walls dulled by soot and streaks of damp. The courtyards between them are narrow, grass clipped too flat, the benches slick with condensation even before night settles. Lamps stutter against the dark, halos broken by the branches that reach in close, and the air carries the taste of exhaust from the parkway mixed with the sharp bite of concrete dust. The stairwells murmur with echoes, footsteps doubling back like the sound is reluctant to let go.\n\nBrookfield Gardens carries an unease that is sharper than silence. The hallways smell of meals you never see served, doors shut tight with locks scarred from too much use. Windows glow in scattered rhythms across the blocks, sudden rectangles of light that blink out as quickly as they appeared. Past midnight the streets run empty, but the buildings watch with their rows of blank eyes, steady and unblinking, as if the whole place is counting down to something it will not say aloud.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Mooney's Bay", "Rideau View", "Billings Bridge"],
	"characters": []
},


"Mooney's Bay": {
	"zone_name": "MooneysBay",
	"default_viewpoint": "main",
	"category": "",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The shoreline stretches wide, sand pale under the weak lamps that line the park. Water lies black and still, rippling only when the wind cuts sharp across its surface, carrying the smell of algae and gasoline from passing boats. The playground structures stand empty, their shapes crooked against the dark, while the steps of the old pavilion echo faintly even when no one moves. Beyond the beach, the trees close in thick, and their shadows spill long across the paths, bending where the light fails.\n\nMooney’s Bay has the feel of something waiting just out of sight. The water reflects almost nothing, swallowing light as if it were never there. Benches face the river like silent witnesses, their backs slick with dew, their seats cold no matter the season. Past midnight the place feels hollowed out, the laughter of summer crowds replaced by a pressure that tightens the air. The wide bay that looks welcoming by day becomes a black mouth at night, open and patient.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Rideau View", "Brookfield Gardens"],
	"characters": []
},


"Carleton University Campus": {
	"zone_name": "CarletonUniversity",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The river bends around the campus like a moat, dark water pressing against the edges of clipped lawns and walkways that stretch too far beneath weak lamps. Buildings rise in blunt shapes of glass and brick, their windows blank after sundown, as if they have been watching too long. The tunnels below hum with stale air, their echoes doubling each step until it feels like someone is following. Even the benches scattered across the quads seem occupied in their stillness, waiting with a patience that does not belong to wood or stone.\n\nCarleton University carries an unease that settles deepest at night. The library looms like a bunker, humming with fluorescent breath, while the residence towers tilt above the river like worn sentries. The wind scrapes at the flagpoles, hollow and metallic, and doors in the underground walkways shut when no one is near. The campus feels staged, a collection of facades too neat to be empty, as though the lecture halls and stairwells are rehearsing for something that never arrives.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Rideau View", "Civic Hospital", "Old Ottawa South"],
	"characters": []
},


"Rideau View": {
	"zone_name": "RideauView",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Concrete towers rise like tired teeth against the river, their faces mottled with mildew and half-covered tags that no one remembers painting. The courtyards between them feel hollow, swings and benches scattered like discarded props, lit only by lamps that crackle in uneven bursts. The stairwells reek of damp and smoke, and when you climb them the echoes carry too long, repeating your steps as though someone else is following just a few paces behind. The smell of the river drifts in, iron-black, thick as oil, and it feels close enough to flood the whole place with a single turn.\n\nThis is Rideau View, carved from old farmland and left standing like a draft of the city that was never corrected. At night it feels temporary and unstable, a place where the air thickens with silence until even breathing sounds suspicious. The windows blink in uneven codes, turning on and off in patterns that suggest a message only the buildings understand. The neighborhood seems to wait with a patience that is not human, as though the streets themselves are counting down toward something you cannot quite see.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Carleton Heights", "Courtland Park", "Carleton University Campus", "Mooney's Bay", "Brookfield Gardens"],
	"characters": []
},


"Chinatown": {
	"zone_name": "Chinatown",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Lantern signs hang crooked over Somerset, their colors dimmed by grime and years of smoke. Restaurants spill steam into the street, clouds that rise and vanish before they touch the lamps, leaving the sidewalks wet and strange. The shops feel too narrow, stacked with goods that smell of dust and oil, and above them the apartments press low, their windows shut tight against the night. Somewhere past the arches, traffic hums like a restless engine, carrying a weight that does not leave.\n\nChinatown in Ottawa feels like it holds its breath after dark. The signs flicker weakly, reds and greens bleeding out before they touch the pavement, and the alleys fold into deeper dark than they should. The air tastes faintly of soy and metal, like a kitchen left burning with no one inside. Stray cats slip across the street without sound, their eyes catching the glow like mirrors. Past midnight, the silence is thick enough to feel, and every shadow looks like it could step forward if given the chance.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Little Italy", "Centretown West", "The Secret Pages"],
	"characters": []
},

# ---------- The Secret Pages Zone ----------
	"The Secret Pages": {
		"zone_name": "The Secret Pages",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The air within this bookstore hangs heavily with a sense of things forgotten, clinging to itself with the lingering scent of aged paper, dust, and something else. Something akin to forgotten secrets. Despite the soft, warm light afforded by afforded by a surplus of stringed paper lanterns, shadows pool in-between the symmetrically arranged shelves of the main floor of the little storefront, as if they seeped up through the floorboards. There's an effort here, a little carving of peace and wonder struggling against the implication of the dark streets outside.

The shelves nearly reach the ceiling, each filled to the brim in orderly little rows of books. Everything has it's place, everything sits perfectly where it belongs, while still offering the compelling mystery of what they might contain. Heavy wooden blinds frame every window in security, keeping the sun off the tomes in the day, and keeping the darkness out now. The stacks part in a cross shape, leading the curious to a lonely counter at the back of the store, which held a shelf brimming with new releases and dated top sellers. A cat sleeps or aloofly lingers just out of reach, it's black coat a reminder of the shadows that linger. An ominous door peers from behind the counter, covered in little charms and markings, blending seamlessly into Chinatown's held breath of anticipation.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Chinatown"],
		"characters": []
	},


"Little Italy": {
	"zone_name": "LittleItaly",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Along Preston Street the restaurants and cafés glow with neon, their signs humming in colors that bleed onto the wet pavement. The air is thick with garlic, oil, and smoke, but under it lingers the iron tang of the train tracks that cut across the neighborhood. Brick façades lean heavy over narrow sidewalks, their upper windows dark, blinds pulled tight as though the families above have retreated from the night. Even the murals seem to fade under the lamps, painted saints and flags peeling into shapes that do not quite stay still.\n\nLittle Italy carries a strange stillness once the kitchens close. The music dies but the echo clings to the alleys, a bassline you feel in your ribs though nothing plays. The benches along the street wait empty, damp beneath the sodium glow, and the intersections stretch too wide, as if holding their breath. Walk long enough and the smell of food gives way to something colder, metallic and sour, the kind of scent that clings to steel. By midnight the neighborhood feels less like a celebration and more like a memory that refuses to sleep.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Civic Hospital", "Hintonburg", "Centretown West", "Lebreton Flats", "Chinatown"],
	"characters": []
},


"Hintonburg": {
	"zone_name": "Hintonburg",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The streets run narrow here, old brick shops pressed close against the road, their painted signs peeling into unreadable ghosts. Factories long since shuttered still breathe rust into the air, their chimneys blackened stubs pointing toward a sky that feels too low. Railway tracks slice through the blocks like scars, the sound of trains gone but their vibration lingering in the ground. Even the taverns spill less light than they should, their doors opening to rooms where laughter always sounds a little too far away.\n\nHintonburg is not dead, but it feels like it is rehearsing the end. The lamps flicker weakly against graffiti-stained walls, and the alleys seem to bend back on themselves, as if trapping whatever wanders in. Dogs bark in languages you almost understand, and sometimes the silence between houses feels like it is counting down. It is a neighborhood caught between what it was and what it will never be again, a place where you wonder if the city is rotting quietly from this very point outward, and whether the world notices or not.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Wellington Village", "Civic Hospital", "Little Italy","The Night Fair","First Mosque of Ottawa"],
	"characters": []
},

# ---------- First Mosque of Ottawa Zone ----------
	"First Mosque of Ottawa": {
		"zone_name": "First Mosque of Ottawa",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The first mosque in Ottawa, opened in 1975, had by the early 1990s become a well-established and recognizable presence within what was then still regarded as a largely stable suburban area. The surrounding neighborhood retained much of its postwar character, defined by family homes, small commercial strips, and a relatively strong sense of local continuity. During this period, the mosque served not only as a place of worship but also as an important social and cultural center for Ottawa’s growing Muslim population, hosting community gatherings, educational programs, and religious observances that drew attendees from across the city.



By the early 1990s, signs of gradual change were beginning to emerge in the area. While the neighborhood was generally considered safe and functional, early indicators of social and economic strain had started to appear. Isolated incidents of gang-related activity and petty crime were increasingly noted, though they had not yet come to define the area’s public reputation. Despite these emerging challenges, the mosque remained well cared for, supported by a committed congregation that included several well-established and comparatively affluent families living nearby.



At this time, the area existed in a transitional state: still benefiting from its suburban foundations and community institutions, yet beginning to experience pressures that would later contribute to more pronounced decline. The mosque’s continued presence and active role in community life during the early 1990s reflected both its resilience and its importance as a stabilizing institution within a neighborhood on the cusp of broader change.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hintonburg"],
		"characters": []
	},
	
# ---------- The Night Fair Zone ----------
	"The Night Fair": {
		"zone_name": "The Night Fair",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "On more nights than not, the fairgrounds of Mechanicsville, Ottawa are alive with the happening and the entertainment provided by the ongoing of 'The Night Fair', A festive and once mobile carnival and circus that on one night decided to make root and remain.
Since then it's been a fixture here, entertainment for all ages only operating after dusk.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hintonburg"],
		"characters": []
	},

"Civic Hospital": {
	"zone_name": "CivicHospital",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The streets rise gently toward the ridge, brick houses standing in neat rows with porches pulled close to the sidewalk. Trees arch overhead, their branches weaving shadows that smother the weak shine of the lamps. The air is heavy with the smell of stone and damp brick, as if the neighborhood itself sweats after sundown. Sirens stretch too long in the night, echoing between the houses until they dissolve into something less like a warning and more like a voice that refuses to fade.\n\nThe Civic Hospital looms at the heart of it, its windows stacked in rigid lines of light that spill coldly across the streets. Around it, the homes feel watchful and withdrawn, curtains sealed against the night, driveways empty even when the cars are still there. Few linger outside once dark settles in. The neighborhood holds quiet in a way that feels deliberate, as though the silence itself is standing guard, and the glow from the wards makes the streets look more like a wake than a place to rest.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Courtland Park", "Carlington", "Hintonburg", "Little Italy", "Carleton University Campus"],
	"characters": []
},


"Courtland Park": {
	"zone_name": "CourtlandPark",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Tucked between the rail line and the curling edge of the Experimental Farm, Courtland Park feels more like a pocket than a neighborhood. The bungalows here are low and plain, set against hedges that have gone shaggy with age, their curtains drawn long before the lamps outside stutter to life. The air carries the flat stench of asphalt from the nearby roads, a taste that clings to the tongue and makes the silence heavier. Even the streetlamps seem reluctant, their glow collapsing just short of the hedgerows, leaving the sidewalks veiled in shadow.\n\nThis is the ground where the Merivale Road once carried cattle north toward the old slaughterhouses near the river, a history buried but not erased. Courtland Park seems to breathe that memory, the empty lots and overgrown fields marked by a quiet that feels more like withholding than peace. After nightfall, the spaces between houses seem to lengthen, as if the neighborhood itself is pulling apart. The air grows close and watchful, and the dark presses in with the sense that every step is tallied by something patient and unseen.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Carleton Heights", "Civic Hospital", "Rideau View"],
	"characters": []
},


"Carleton Heights": {
	"zone_name": "CarletonHeights",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "South of the river the streets stretch wide, broken by sagging lawns and driveways split like old scars. Duplexes lean into one another, their bricks damp with the night air, their curtains pulled as if the houses themselves were keeping secrets. Power lines whistle when the wind cuts through, a thin note that lingers longer than it should, and the lamps overhead buzz faintly like they are holding back the dark. The smell of wet asphalt mixes with cut grass and something sour that clings to the ditches along Prince of Wales.\n\nCarleton Heights feels unfinished, a neighborhood sketched too quickly and left to fade at the edges. The space here does not breathe like freedom, it gapes like vacancy, echoing when you walk alone. Dogs bark at nothing, and sometimes the silence that follows seems louder than their warning. The schoolyards grow heavy after sundown, playgrounds watching with more patience than their shape should allow. The quiet scratches at the nerves, a soundless pressure that feels like someone trying to speak.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Carlington", "Courtland Park", "Rideau View"],
	"characters": []
},


"Wellington Village": {
	"zone_name": "WellingtonVillage",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Shops line Wellington like teeth in a crooked grin, their painted signs faded, their windows clouded by dust and old light. Above them, narrow apartments squeeze against one another, brick walls scarred by smoke and the scrape of wires. The side streets feel tighter than they should, rows of homes crouched close, their porches sunken into shadow beneath thick maples. Even in daylight there is a hush to the air, as if conversation belongs behind doors, not on the pavement.\n\nThis is Wellington Village, where the lamps burn with a dull glow and the alleys seem to bend into darker turns than the maps remember. At night the storefront glass reflects more than it should, passing shapes that no one steps out to follow. The hum of the streetcars is gone, but sometimes the rails sing anyway, a metallic shiver under the asphalt. By midnight the neighborhood feels sealed, its silence too careful, its sleep too thin.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Westboro", "Hintonburg"],
	"characters": []
},


"Carlington": {
	"zone_name": "Carlington",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "On the western slope of Ottawa, rows of bungalows climb around a scarred hill where an old quarry pond sits stagnant and dark, its edges littered with weeds and glass. The wind twists strangely over the ridge, carrying whistles that sometimes sharpen into voices too close to human.\n\nThis is Carlington, a neighborhood that feels watchful even when nothing stirs. Streetlights along Kirkwood and Fisher hum weakly, while the alleys run deeper into shadow than they should. Garages rust at the margins, the churches close their doors early, and by midnight the hill glows faintly under city light, circled by houses that never seem to rest.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Westboro", "McKellar Heights", "Carleton Heights", "Civic Hospital"],
	"characters": []
},

"Westboro": {
	"zone_name": "Westboro",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The homes along Richmond Road pretend to be modest, but the street carries memory like a watermark. Once a lumber town, then a village of rail-men and river work, Westboro was annexed into Ottawa as if absorbed into a greater body. Yet the lines of ownership still twitch. Warehouses stand among boutiques, and the old factories have not fully surrendered to renovation. The Ottawa River lies just beyond the rise, a reminder that the neighborhood owes its existence to current and commerce more than to civic design.\n\nIn the alleys behind the storefronts, brick walls lean under the weight of signs in both languages, though neither fully convinces. Churches with tired steps look down on quiet cafés, as if waiting for judgment. Every door carries a history, but none of them are fully open. The neighborhood is observed, recorded, and kept, like a file stored in the wrong cabinet but never thrown away.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Highland Park", "Carlington", "Wellington Village", "Westboro Mental Clinic"],
	"characters": []
},
# ---------- Westboro Mental Clinic Zone ----------
	"Westboro Mental Clinic": {
		"zone_name": "Westboro Mental Clinic",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A small brick building with a peaked roof, tightly squeezed between residential buildings, the clinic seems hidden from view in a narrow alley, tucked away among balconies and metal fences. The building is so unassuming that it's difficult to find any signs. But upon closer inspection, the façade appears quite welcoming and even cozy. A lone streetlamp casts light on the modest front door and barred windows. It's only three stories tall, one of which is occupied entirely by the staff. The clinic is run by a certain Dr. N.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Westboro", "Mental Clinic: Lobby"],
		"characters": []
	},

# ---------- Mental Clinic: Lobby Zone ----------
	"Mental Clinic: Lobby": {
		"zone_name": "Mental Clinic: Lobby",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The main lobby greets visitors warmly. The reception desk is almost always empty, but the footsteps and conversations of clinic staff can be heard occasionally through the slightly open doors. In the far corner is a staircase leading to the second floor. A sign warns that entry is restricted to staff or relatives of patients by appointment only.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Westboro Mental Clinic"],
		"characters": []
	},

# ---------- Mental Clinic: Second Floor Zone ----------
	"Mental Clinic: Second Floor": {
		"zone_name": "Mental Clinic: Second Floor",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A second-floor corridor lined with several doors. These are all patient rooms. The doors are rarely closed, but each one has a special lock that can instantly transform a cozy room into a locked cage. From within the rooms, one can hear faint sighs, shuffling footsteps, broken sentences, and even a radio.
At the very end of the corridor, near the large door to the break room, there's another staircase.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Mental Clinic: Lobby","Mental Clinic: Attic Workshop","Mental Clinic: Mori's Room","Mental Clinic: Dr. N's Office" ],
		"characters": [],
		"secret_entry_passwords": ["Vulture"],
		"accessible_from_zones": ["Mental Clinic: Lobby"]
	},

# ---------- Mental Clinic: Dr. N's Office Zone ----------
	"Mental Clinic: Dr. N's Office": {
		"zone_name": "Mental Clinic: Dr. N's Office",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The doctor's small office, where he seems to prefer to both live and work. Next to the desk is a bed. A large, comfortable chair, intended not for himself, but for those he's willing to listen to. The doctor is rarely found in office, as he's constantly absorbed in his work and the care of the clinic. The staff describes him as a very kind man with a big heart. It seems as if those around him have forgotten that the doctor hasn't aged much in years, remaining vigorous and robust in appearance, though not a young man.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Mental Clinic: Second Floor"],
		"characters": []
	},

# ---------- Mental Clinic: Mori's Room Zone ----------
	"Mental Clinic: Mori's Room": {
		"zone_name": "Mental Clinic: Mori's Room",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A rather cozy room, filled with 'creative disarray'. The table, shelves, cabinets, and nightstands are filled primarily with handmade figurines. The large window is enveloped in incredibly long, thick curtains. A flock of wooden birds, suspended on strings, hangs above the bed, inspiring a feeling of either cradle-like tranquility or a sense of uneasy restlessness. The bed is carelessly made, and the pile of rumpled pillows seems to suggest the room's owner is often troubled by nightmares. The walls are covered with numerous sketches, sheets of paper with notes and drawings hung haphazardly. Scratches, scuffs, and signs of restless activity can be seen on objects around the room, and the wallpaper is peeling in places. Something silver glistens from the slightly open wardrobe. Despite this, the room can't be described as untidy or dirty. Rather, it seems worn out by time and sorrow.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Mental Clinic: Second Floor"],
		"characters": []
	},

# ---------- Mental Clinic: Attic Workshop Zone ----------
	"Mental Clinic: Attic Workshop": {
		"zone_name": "Mental Clinic: Attic Workshop",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The attic is a small, cramped workshop beneath a triangular, pointed roof. Opposite a small, narrow window, beneath the ceiling beams, hangs a huge stuffed bird. Although, upon closer inspection, it's not a stuffed bird, but rather a puppet, made of either wood or bone. The bird looms menacingly over the workshop, its wings spread wide. It seems as if, were it not for the ropes that bind it, it would pounce on the first person to enter the room. The walls are covered with sketches and blueprints, and parts of toy figurines hang from everywhere. Half-finished wooden birds peer out from all sides with their empty sockets, perched along the roof, on shelves and racks, filling the worktable and floor. Scattered in the corners are a multitude of sticks and pieces of wood, tools, ropes, and feathers. Typically, such places are full of dust, but the attic is clearly cleaned regularly. As much as possible...
This place could almost be called an atmospheric work nook if it weren't for that weird huge thing hanging over your head, like a feathered reaper.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Mental Clinic: Second Floor"],
		"characters": []
	},



"McKellar Heights": {
	"zone_name": "McKellarHeights",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "A quiet grid between traffic veins, bordered by routine and clipped cedar. McKellar Heights doesn’t announce itself. It begins. One bungalow at a time. Lawns at regulation height. Driveways with two cars, both idling through retirement. The houses are close but not curious. Curtains drawn just enough to signal occupancy.\n\nThere is no center here. No plaza. No café with regulars. Just a church with a gravel lot and a park shaped like an afterthought. The signs are bilingual, the conversations are not. Even the birds seem to know when to stop singing. Somewhere behind one of the garages, a tool was left out and rusted into memory. No one touches it. Nothing is wasted. Nothing is explained.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Highland Park", "Woodroffe North"],
	"characters": []
},



"Highland Park": {
	"zone_name": "HighlandPark",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The homes were first laid out in the 1920s, back when Highland Park marked the western edge of Ottawa’s ambition. Built for professionals and government men who didn’t want to live downtown, the neighborhood took its shape from the streetcar line that once ran down Byron. Some of those rails still surface after heavy rain, pushing through the asphalt like reminders. The houses are large but quiet. Brick, wood, and old money.\n\nWalk the side streets and you’ll notice it. The same cars parked in the same places. The same dog walked at the same hour. Conversations are brief, polite, and never repeated. The library gets quiet visits. The cafés serve one drink well. Along the edge of the neighborhood, facing the parkway, there’s an abandoned tennis court no one tears up. The net is gone, but the lines are still visible. Everyone sees them. No one steps on them.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Carlingwood", "McKellar Heights", "Westboro"],
	"characters": []
},



"Woodroffe North": {
	"zone_name": "WoodroffeNorth",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The houses in Woodroffe North are older than they look. Set between the river and the transitway, their brickwork hides additions, retrofits, decades of quiet reshaping. Trees line the streets like they were planted with ceremony, now tall enough to cast shade over everything that followed. The roads here don’t connect so much as parallel. A layout made to be respected, not understood.\n\nDown near Richmond Road, the storefronts still hold their original signs, the kind with hand-painted letters and aging neon. Schools and churches are never far apart. At night, the sound of traffic from the Parkway blends with the wind through the trees, never quite fading, never quite loud. People who live here tend to stay. Not because of loyalty, but because the place is already calibrated to them. It remembers how they move. How they speak. What they prefer to keep private.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Lincoln Heights", "Carlingwood", "McKellar Heights"],
	"characters": []
},



"Carlingwood": {
	"zone_name": "Carlingwood",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Carlingwood does not change quickly. Built around the shopping centre that gave it a name, the neighborhood settled early into its patterns. Bungalows with carports and hedge-lined yards. Seniors walking the same loop each morning. A library that still smells like the 1970s. The streets are wide and soft-spoken, curving gently between the mall, the churches, and the long shadow of the Queensway.\n\nThe mall itself is still clean, still humming. Escalators run smooth. Muzak plays without irony. People shop here because they always have. Most of them remember when it opened. Carlingwood was never meant to be a destination. It was a solution. A place for widows and former bookkeepers. A place where people nod to each other without speaking, and where nothing is urgent except the bus schedule. The city surrounds it now, but doesn’t enter.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Lincoln Heights", "Woodroffe North", "Highland Park"],
	"characters": []
},




"Eastway Gardens": {
	"zone_name": "Eastway Gardens",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Tucked into a hard corner of Alta Vista’s northern edge, it sits between Industrial Avenue, Russell Road, Belfast Road, and St. Laurent Boulevard, forming a square of housing boxed in by movement, noise, and freight. Rail lines run beside it. Trucks idle just beyond the tree line. There are no soft edges here. The houses are close, the lots small. Backyards back into chain-link fences or warehouse lots. At night, the sound of metal on metal from the freight lines can shake picture frames. Some families claim their children sleep better that way.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Elmvale Acres", "Riverview", "Riverside Hospital"],
	"characters": []
},


"Riverview": {
	"zone_name": "Riverview",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The Ottawa General Hospital, the CHEO campus, the National Defence Medical Centre. Massive, sterile facilities that pull gravity toward them like stars. Around them rose the apartment blocks: Alta Vista Towers, cooperative housing, seniors’ residences, low-income towers meant to solve problems that were never defined clearly in the first place. Squeezed between arterial roads, industrial boundaries, and the surgical hum of its medical core, the neighborhood stretches from Smyth to Heron, from Riverside to Industrial Avenue.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Eastway Gardens", "Elmvale Acres", "Riverside Hospital", "Alta Vista"],
	"characters": []
},

"Faircrest Heights": {
	"zone_name": "Faircrest Heights",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Faircrest Heights is a fortress without walls. Bounded by Smyth Road, the Rideau River, and the skeletal reach of the Ottawa General Hospital, the neighborhood exists in a state of perfected seclusion. It remains one of the only zones in Alta Vista where zoning has never been meaningfully contested. There are no businesses here. No towers. No renters. Just silence, clipped hedges, and generational property lines marked in paperwork. The homes are large but not showy, intentionally neutral. Two-storey houses with narrow sightlines, low bungalows flanked by old maples. Driveways curve like questions no one wants to answer.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Riverside Hospital", "Alta Vista", "Applewood Acres", "Billings Bridge"],
	"characters": []
},

"Applewood Acres": {
	"zone_name": "Applewood Acres",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The houses are modest, almost shy. Bounded by Kilborn Avenue, Heron Road, Bank Street, and the CN rail line, the neighborhood was one of Ottawa’s earliest experiments in total suburban design. It was shaped into a perfect little grid designed to absorb the postwar boom like a sponge. Campeau Corporation laid it out in the 1950s with military precision: rows of nearly identical bungalows, short walking distances, no commercial agitation. Commercial activity was zoned out. The only shops are just beyond reach. Everything here directs you outward for needs and inward for behavior. Schools like Ridgemont High taught structure, not ambition. Parks were placed like pressure valves.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Faircrest Heights", "Billings Bridge", "Alta Vista", "Riverview"],
	"characters": []
},

"Alta Vista": {
	"zone_name": "Alta Vista",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "To the north, the hospital complex looms. Ottawa General. CHEO. The National Defence Medical Centre. The community is a satellite array: civil servants, military clerks, radiology technicians. Parks like Featherston and Orlando exist mostly to soak up sound. Some nights, porch lights across three blocks all go out at the exact same minute. The layout is textbook: curving roads designed to reduce speed and thought, bungalows dropped like rubber stamps, zoning locked tight. Not one laundromat. Not one bar. Nothing unapproved.",
			"sound_path": ""
		}
	},
	"connected_zones": ["Riverview", "Riverside Hospital", "Faircrest Heights", "Applewood Acres"],
	"characters": []
},


"Lincoln Heights": {
	"zone_name": "LincolnHeights",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "Lincoln Heights was carved out in the postwar swell, part of the city’s quiet push westward. It was never meant to dazzle. It was meant to function. Modest bungalows for public servants, walk-up apartments for clerks and telephonists, all placed with bureaucratic precision near the new transit loop and federal offices. The roads curve gently, not to follow the land but to manage it. The green spaces are wide, but no one sits in them for long.\n\nThe shopping centre opened in the 1960s with fanfare. There was a fountain once. Now the tiles are cracked, and the lights buzz even when it’s empty. The transit station across the boulevard feeds the city its workers and retrieves them after dark, quiet and unbroken. Inside the towers, blinds are always drawn. Conversations take place at kitchen tables under fluorescent light. There are no festivals here. No corner stores open past nine. Just routine, and the sound of the next bus arriving on schedule.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Britannia Heights", "Carlingwood", "Woodroffe North"],
	"characters": []
},


"Britannia Heights": {
	"zone_name": "BritanniaHeights",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The houses climb gently uphill, set back from the water but still within its reach. Britannia Heights grew as the streetcars did, one block at a time, grafted onto farmland by planners who believed order could be drawn with a ruler. Bungalows with trimmed hedges, Catholic schools with tall fences, and churches that watch from corners without blinking. Everything here is measured. Even the cracks in the sidewalk follow a pattern.\n\nThe families are older now. Some never left. Most work in departments no one talks about outside the office. There is a silence to the streets after dinner, a pause that stretches longer than it should. The streetlights flicker, but only once. Lawn ornaments shift slightly between seasons, always facing the same way. Behind the community centre, someone has been mowing a field that no one remembers using. Not out of care. Out of instruction.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Lincoln Heights", "Britannia Village", "The Wellington at Brittania"],
	"characters": []
},

# ---------- The Wellington at Brittania Zone ----------
	"The Wellington at Brittania": {
		"zone_name": "The Wellington at Brittania",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "The Wellington at Brittania looks like any other unremarkable retirement community across Ottawa by day, but at night its true character settles over it like a heavy curtain. The building rises in blocky tiers of beige brick and shadowed balconies, the kind of architecture that leaves little impression to passerby. From the street, its windows glow in a scattered pattern - warm pools of lamplight from those few residents that are still awake at this hour. The rest are dark, curtains slightly parted as if someone could be watching from any one of these dark places.The air here is still, with the kind of overbearing quiet that means more than a lack of sound. Even the winds that sweep their way across the river seem to hesistate before blowing over the property line.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Brittania Heights"],
		"characters": []
	},

# ---------- Harvey's Condo Zone ----------
	"Harvey's Condo": {
		"zone_name": "Harvey's Condo",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Harvey’s condo, perched near the top floor of The Wellington at Britannia, is an eccentric blend of the mundane and the unsettling. The two-bedroom unit has the faded floral wallpaper and worn beige carpeting typical of early ’70s construction, with one bedroom serving as a modest sleeping space and the other repurposed entirely for Harvey’s obsessions. The living room is cluttered with stacks of newspapers, books, and half-finished crossword puzzles, while a sagging armchair sits by the window overlooking the Ottawa River. The air carries the faint, lingering scent of pipe tobacco and dust, giving the space a sense of long-term habitation and quiet neglect.

The second bedroom, however, has been transformed into a dark room, its door perpetually closed, exuding a palpable hum of hidden energy. Across one wall of the living area, a sprawling conspiracy board dominates the room, covered in yellowed clippings, photographs, red string, and cryptic notes linking seemingly unrelated events and Kindred. Shadows cling unnaturally to corners, and the ceiling fan hums at an irregular rhythm as if the apartment itself is alive with some form of otherworldly awareness. To mortal visitors, it is cluttered but cozy; to a Kindred, every flicker of light, every whisper of movement, and every shadowed nook makes it clear: this is Harvey’s domain - a carefully curated space for observation, secrets, and control.",
				"sound_path": ""
			},
		},
		"connected_zones": ["The Wellington at Brittania"],
		"characters": [],
		"secret_entry_passwords": ["nightcrawler"],
		"accessible_from_zones": ["The Wellington at Brittania"]
	},


"Britannia Village": {
	"zone_name": "BritanniaVillage",
	"default_viewpoint": "main",
	"category": "ottawa_high_outside",
	"is_neighborhood": true,
	"viewpoints": {
		"main": {
			"image_path": "",

			"description": "The street grid bends here, forced to accommodate what came before it. Britannia Village was a lakeside resort once, long before the capital swallowed it. Old foundations still surface in the soil after rain. Stone steps lead to nowhere. Brick outlines of vanished cottages emerge like quiet admissions. The tram used to stop near the water. It doesn’t anymore. The tracks were pulled up, but some nights you can still hear it. Metal on metal, just under the wind.\n\nPorches sag toward the Ottawa River, screened in and watching. Retired civil servants keep long memories and short conversations. The hydro station hums at all hours, its red warning lights blinking across the reeds like a signal no one speaks of. Every house has a locked drawer. The Dominion Observatory sits not far from here, blind and silent, still fenced off like it remembers what it once saw. Britannia waits at the western edge of the city, behind hedge and policy, perfectly still. It was archived, not abandoned. The filing cabinet just never closed.",
			"sound_path": ""

		}
	},
	"connected_zones": ["Rowatt St", "Britannia Heights"],
	"characters": []
},

# ---------- Rowatt St Zone ----------
	"Rowatt St": {
		"zone_name": "Rowatt St",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": false,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Rowatt Street isn't much in the way of interesting. Simple houses line a simple street, and for the most part? It's quiet here. People mind their business and keep opinions to themselves. 

At the end of the street, a right turn will take you to a large home, older but still well maintained (at least externally). Rumor has it the lady of the house rarely leaves, and no one sees her doing so if she does.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Britannia Village"],
		"characters": []
	},


# ---------- Hunt Club Park Zone ----------
	"Hunt Club Park": {
		"zone_name": "Hunt Club Park",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "South of Walkley, east of Conroy, the fields have only just stopped being fields. The air still carries the smell of cut trees and disturbed soil. A handful of homes are finished. Some have families in them. There are fewer than fifteen hundred residents here. The streetlights work, but not all of them.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Urbandale"],
		"characters": []
	},

# ---------- Urbandale Zone ----------
	"Urbandale": {
		"zone_name": "Urbandale",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A branded enclosure stamped across southeastern Ottawa by Urbandale Construction, like the signature of a civil engineer who feared chaos.Three to four thousand residents lived in Urbandale by 1990. Most were Anglophone, most paid their property taxes on time. The parks were maintained. The lawns were edged. Urbandale is holding up patterns, the streets are clean. The people are good. And the silence under the topsoil is growing louder",
				"sound_path": ""
			},
		},
		"connected_zones": ["Hunt Club Park", "Elmvale Acres", "Hawthorne Meadows"],
		"characters": []
	},

# ---------- Hawthorne Meadows Zone ----------
	"Hawthorne Meadows": {
		"zone_name": "Hawthorne Meadows",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Built during the second wave of Ottawa s expansion, its shape was drawn with a kind of doctrinal certainty: looping roads to create false safety, pocket parks like planned sacraments, rows of homes identical in posture but not in soul. Bordered by Walkley, St. Laurent, Russell, and the CN line, it sits like a quietly humming machine, neither hidden nor truly visible. Nothing looks broken. Nothing shines. There are no monuments here, only compliance.",
				"sound_path": ""
			},
		},
		"connected_zones": ["Urbandale", "Elmvale Acres", "Sheffield Glen"],
		"characters": []
	},

# ---------- Sheffield Glen Zone ----------
	"Sheffield Glen": {
		"zone_name": "Sheffield Glen",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "A self-contained tract of low-rise housing tucked between Russell and Belfast like an afterthought, laid out in the curving grid of Southvale Crescent where roads loop endlessly back to themselves.Townhouses, garden homes, and rental blocks planted in quiet density, engineered for moderate income and manageable unrest. There are no local businesses.In 1990, two to three thousand people lived in Sheffield Glen. No parks. No schools. Just housing and the roads to take you somewhere else. Most were Anglophone, many were new arrivals from Lebanon, Romania, and El Salvador, moved here by circumstance more than choice",
				"sound_path": ""
			},
		},
		"connected_zones": ["Elmvale Acres", "Hawthorne Meadows"],
		"characters": []
	},

# ---------- Elmvale Acres Zone ----------
	"Elmvale Acres": {
		"zone_name": "Elmvale Acres",
		"default_viewpoint": "Main",
		"category": "",
		"is_neighborhood": true,
		"viewpoints": {
			"Main": {
				"image_path": "",

				"description": "Mid-1950s, Campeau Corporation, a vision of modest utopia laid out in cul-de-sacs and quiet loops. Bungalows repeated like standardized answers. No room for ambition. No space for rot. South of Alta Vista, east of the General Hospital. The Elmvale Acres Shopping Centre served as the local heart, beating in fluorescent pulses. No frills, no flash. A pharmacy, a grocer, a dry cleaner with one broken press and three active service requests. Ottawa s hospital belt lay to the west, meaning half the residents worked shift schedules and spoke in clinical terms even at PTA meetings. Transit routes fed into the neighborhood like arteries from elsewhere, but few took the bus out unless they had to. ",
				"sound_path": ""
			},
		},
		"connected_zones": ["Urbandale", "Eastway Gardens"],
		"characters": []
	},
}








func _ready():
	print("🧪 Zone list:", zones.keys())
	print("🌐 ZoneManager ready. Is server:", multiplayer.is_server())

func move_character_to_zone(character: Resource, target_zone_name: String) -> void:
	var character_name: String = character.name
	var current_zone_name: String = character.current_zone

	print("🗺️ [Zone] move_character_to_zone():", character_name, " → ", target_zone_name, " (from:", current_zone_name, ")")

	# 🧹 Notify departure and remove from old zone
	if zones.has(current_zone_name):
		MessagesManager.notify_zone_change("departure", character_name, current_zone_name)

		zones[current_zone_name]["characters"] = zones[current_zone_name]["characters"].filter(
			func(c): return c.name != character_name
		)

	# 🛡 Ensure target zone exists with viewpoint support
	if not zones.has(target_zone_name):
		print("❌ Attempted to move to undefined zone:", target_zone_name)
		return

	var target_zone = zones[target_zone_name]

	# ✅ Add character to new zone and notify arrival
	if character not in target_zone["characters"]:
		target_zone["characters"].append(character)
		MessagesManager.notify_zone_change("arrival", character_name, target_zone_name)

	# 🎯 Update character's zone and viewpoint
	character.current_zone = target_zone_name
	character.current_viewpoint = target_zone["default_viewpoint"]

	# 🌆 Update character's current zone category
	character.current_zone_category = target_zone.get("category", "")

	# 🩸 RESET any temporary blood-buffed physicals on zone change (server-side call)
	var net := get_node("/root/NetworkManager")
	if net and net.has_method("request_reset_physical_blood_bonuses"):
		print("🩸 [Zone] Resetting blood buffs for:", character_name)
		# Call directly on the server (no RPC hop needed here)
		net.request_reset_physical_blood_bonuses(character_name)
	else:
		print("⚠️ [Zone] NetworkManager missing or method not found; skip blood reset")

	# 🔍 Get peer ID if character is controlled
	var peer_id = GameManager.character_peers.get(character_name, -1)

	if peer_id == -1:
		print("👻", character_name, "is unassigned (NPC or inactive player). No peer updates sent.")
		return  # Stop here — we don't send anything to unassigned characters

	# ✅ Send zone updates to controlled peer
	rpc_id(peer_id, "receive_zone_category", character.current_zone_category)

	var characters = zones.get(target_zone_name, {}).get("characters", [])
	var names: Array[String] = []
	for other_char in characters:
		if other_char.name != character_name:
			names.append(other_char.name)

	rpc_id(peer_id, "receive_zone_character_list", names)
	NetworkManager.rpc_id(peer_id, "flush_typing_state")

	var vp_id = character.current_viewpoint
	var vp_data = target_zone.get("viewpoints", {}).get(vp_id, {})
	var img_path = vp_data.get("image_path", "")

	rpc_id(peer_id, "receive_viewpoint_image", {
		"image_path": img_path,
		"char_name": character_name
	})

	NetworkManager.send_character_data_to_peer(character, peer_id)
	print("✅ [Zone] Move complete for", character_name, "→", target_zone_name)




@rpc("authority")
func receive_new_zone_data(zone_name: String, zone_data: Dictionary) -> void:
	ZoneManager.zones[zone_name] = zone_data

	# 🔄 Reset any temporary blood-buffed physicals when zone data is refreshed
	if GameManager.character_data:
		NetworkManager.rpc("request_reset_physical_blood_bonuses", GameManager.character_data.name)



var temp_zone_timers: Dictionary = {}


func start_temp_zone_cleanup_timer(zone_name: String) -> void:
	if temp_zone_timers.has(zone_name):
		return # Timer already running

	var timer := Timer.new()
	timer.wait_time = 3600.0 # 1 hour
	timer.one_shot = false
	timer.autostart = true
	timer.name = "TempZoneTimer_" + zone_name
	timer.timeout.connect(_on_temp_zone_timer_timeout.bind(zone_name))
	add_child(timer)
	temp_zone_timers[zone_name] = timer

func _on_temp_zone_timer_timeout(zone_name: String) -> void:
	if not zones.has(zone_name):
		print("⛔ Temp zone no longer exists:", zone_name)
		_stop_and_remove_temp_timer(zone_name)
		return

	var zone_data: Dictionary = zones[zone_name]
	if zone_data.get("characters", []).is_empty():
		print("🧹 Removing empty temporary zone:", zone_name)
		zones.erase(zone_name)
		_stop_and_remove_temp_timer(zone_name)

func _stop_and_remove_temp_timer(zone_name: String) -> void:
	if temp_zone_timers.has(zone_name):
		var timer: Timer = temp_zone_timers[zone_name]
		timer.queue_free()
		temp_zone_timers.erase(zone_name)

@rpc("any_peer", "reliable")
func receive_zone_character_list(_names: PackedStringArray) -> void:
	# No-op on server; clients already handle via their own logic/UI.
	# Leaving empty prevents server log errors without affecting flow.
	pass

@rpc("any_peer", "reliable")
func receive_viewpoint_image(_image_path: String, _description: String, _sound_path: String = "") -> void:
	# No-op stub to satisfy RPC config on the sender.
	pass
