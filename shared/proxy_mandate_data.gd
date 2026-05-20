class_name ProxyMandateData
extends Resource
## A proxy mandate assigned by a lord to a courtier per GDD s16.2.
## Defines the scope of binding commitments the proxy may make on the lord's behalf.

@export var lord_id: int = -1
@export var proxy_id: int = -1
@export var mandate_topic_id: int = -1
@export var decision_authority: bool = false
@export var depth_limit: int = -1
@export var out_of_mandate_flag: bool = false
@export var assigned_ic_day: int = -1
@export var court_id: int = -1
