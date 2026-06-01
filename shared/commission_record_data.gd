class_name CommissionRecordData
extends Resource
## Tracks an active art commission per GDD s57.23.5 and s57.23.5a.
## Created when an artisan accepts a CULTIVATE_GARDEN commission (via OFFER_ART_COMMISSION,
## REQUEST_ART, or ASSIGN_VASSAL_OBJECTIVE). Persists until the commission reaches
## a terminal status (COMPLETED, ABANDONED, CANCELLED, FORGIVEN, CREATOR_DECEASED).

@export var commission_id: int = -1
@export var artisan_id: int = -1
@export var daimyo_id: int = -1
@export var settlement_id: int = -1

## Zone type: "CASTLE_OUTER_COURTYARD" or "TSUBONIWA"
@export var zone_type: String = ""

## Always "garden" for GardenSystem commissions.
@export var art_form: String = "garden"

## Action that created this commission.
## One of: "OFFER_ART_COMMISSION", "REQUEST_ART", "ASSIGN_VASSAL_OBJECTIVE"
@export var source_action_id: String = ""

## Commission status.
## "ACTIVE" — ongoing; "SUSPENDED" — temporarily paused;
## "ABANDONED" — artisan failed to meet the completion window;
## "COMPLETED" — garden was successfully installed;
## "CANCELLED" — cancelled before completion (no consequences);
## "FORGIVEN" — abandoned but lord forgave after appeal;
## "CREATOR_DECEASED" — artisan died mid-commission.
@export var status: String = "ACTIVE"

## Accumulated cultivation progress toward QUALITY_THRESHOLD[target_quality_tier].
@export var cultivation_progress: int = 0

## Quality tier the artisan is working toward (1=Normal..5=Legendary).
@export var target_quality_tier: int = 1

## IC seasons elapsed in ACTIVE status without any CULTIVATE_GARDEN AP spent.
## Only begins incrementing after window_start_date is set (i.e., after first AP spent).
@export var neglect_timer: int = 0

## Completion window in IC seasons (0 for non-obligated commissions).
## Set from COMPLETION_WINDOW_BY_TIER when source_action_id is ASSIGN_VASSAL_OBJECTIVE.
@export var completion_window: int = 0

## IC day of the first CULTIVATE_GARDEN AP spent. -1 until the artisan begins work.
@export var window_start_date: int = -1

## Progress accumulated at the time the commission was abandoned. -1 until ABANDONED.
@export var progress_at_abandonment: int = -1

## IC season in which a forgiveness appeal was filed. -1 = no appeal yet.
@export var forgiveness_appeal_season: int = -1

## IC day the commission record was created.
@export var creation_date: int = -1
