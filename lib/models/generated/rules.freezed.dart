// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../rules.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RuleSetView {

 String get name; String get behavior; int get count;@JsonKey(name: 'updated-at') DateTime? get updatedAt; String get vehicle; String get status; int get interval;
/// Create a copy of RuleSetView
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleSetViewCopyWith<RuleSetView> get copyWith => _$RuleSetViewCopyWithImpl<RuleSetView>(this as RuleSetView, _$identity);

  /// Serializes this RuleSetView to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RuleSetView;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleSetView&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.behavior, _this.behavior) || other.behavior == _this.behavior)&&(identical(other.count, _this.count) || other.count == _this.count)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.vehicle, _this.vehicle) || other.vehicle == _this.vehicle)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.interval, _this.interval) || other.interval == _this.interval));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RuleSetView;
  return Object.hash(runtimeType,_this.name,_this.behavior,_this.count,_this.updatedAt,_this.vehicle,_this.status,_this.interval);
}

@override
String toString() {
  final _this = this as RuleSetView;
  return 'RuleSetView(name: ${_this.name}, behavior: ${_this.behavior}, count: ${_this.count}, updatedAt: ${_this.updatedAt}, vehicle: ${_this.vehicle}, status: ${_this.status}, interval: ${_this.interval})';
}


}

/// @nodoc
abstract mixin class $RuleSetViewCopyWith<$Res>  {
  factory $RuleSetViewCopyWith(RuleSetView value, $Res Function(RuleSetView) _then) = _$RuleSetViewCopyWithImpl;
@useResult
$Res call({
 String name, String behavior, int count,@JsonKey(name: 'updated-at') DateTime? updatedAt, String vehicle, String status, int interval
});




}
/// @nodoc
class _$RuleSetViewCopyWithImpl<$Res>
    implements $RuleSetViewCopyWith<$Res> {
  _$RuleSetViewCopyWithImpl(this._self, this._then);

  final RuleSetView _self;
  final $Res Function(RuleSetView) _then;

/// Create a copy of RuleSetView
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? behavior = null,Object? count = null,Object? updatedAt = freezed,Object? vehicle = null,Object? status = null,Object? interval = null,}) {
  return _then(RuleSetView(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,behavior: null == behavior ? _self.behavior : behavior // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,vehicle: null == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,interval: null == interval ? _self.interval : interval // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RuleSetView].
extension RuleSetViewPatterns on RuleSetView {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleSetView value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleSetView() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleSetView value)  $default,){
final _that = this;
switch (_that) {
case _RuleSetView():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleSetView value)?  $default,){
final _that = this;
switch (_that) {
case _RuleSetView() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String behavior,  int count, @JsonKey(name: 'updated-at')  DateTime? updatedAt,  String vehicle,  String status,  int interval)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleSetView() when $default != null:
return $default(_that.name,_that.behavior,_that.count,_that.updatedAt,_that.vehicle,_that.status,_that.interval);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String behavior,  int count, @JsonKey(name: 'updated-at')  DateTime? updatedAt,  String vehicle,  String status,  int interval)  $default,) {final _that = this;
switch (_that) {
case _RuleSetView():
return $default(_that.name,_that.behavior,_that.count,_that.updatedAt,_that.vehicle,_that.status,_that.interval);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String behavior,  int count, @JsonKey(name: 'updated-at')  DateTime? updatedAt,  String vehicle,  String status,  int interval)?  $default,) {final _that = this;
switch (_that) {
case _RuleSetView() when $default != null:
return $default(_that.name,_that.behavior,_that.count,_that.updatedAt,_that.vehicle,_that.status,_that.interval);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuleSetView extends RuleSetView {
  const _RuleSetView({this.name = '', this.behavior = '', this.count = 0, @JsonKey(name: 'updated-at') this.updatedAt, this.vehicle = '', this.status = 'ok', this.interval = 0}): super._();
  factory _RuleSetView.fromJson(Map<String, dynamic> json) => _$RuleSetViewFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String behavior;
@override@JsonKey() final  int count;
@override@JsonKey(name: 'updated-at') final  DateTime? updatedAt;
@override@JsonKey() final  String vehicle;
@override@JsonKey() final  String status;
@override@JsonKey() final  int interval;

/// Create a copy of RuleSetView
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleSetViewCopyWith<_RuleSetView> get copyWith => __$RuleSetViewCopyWithImpl<_RuleSetView>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuleSetViewToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleSetView&&(identical(other.name, name) || other.name == name)&&(identical(other.behavior, behavior) || other.behavior == behavior)&&(identical(other.count, count) || other.count == count)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vehicle, vehicle) || other.vehicle == vehicle)&&(identical(other.status, status) || other.status == status)&&(identical(other.interval, interval) || other.interval == interval));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,behavior,count,updatedAt,vehicle,status,interval);
}

@override
String toString() {
    return 'RuleSetView(name: $name, behavior: $behavior, count: $count, updatedAt: $updatedAt, vehicle: $vehicle, status: $status, interval: $interval)';
}


}

/// @nodoc
abstract mixin class _$RuleSetViewCopyWith<$Res> implements $RuleSetViewCopyWith<$Res> {
  factory _$RuleSetViewCopyWith(_RuleSetView value, $Res Function(_RuleSetView) _then) = __$RuleSetViewCopyWithImpl;
@override @useResult
$Res call({
 String name, String behavior, int count,@JsonKey(name: 'updated-at') DateTime? updatedAt, String vehicle, String status, int interval
});




}
/// @nodoc
class __$RuleSetViewCopyWithImpl<$Res>
    implements _$RuleSetViewCopyWith<$Res> {
  __$RuleSetViewCopyWithImpl(this._self, this._then);

  final _RuleSetView _self;
  final $Res Function(_RuleSetView) _then;

/// Create a copy of RuleSetView
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? behavior = null,Object? count = null,Object? updatedAt = freezed,Object? vehicle = null,Object? status = null,Object? interval = null,}) {
  return _then(_RuleSetView(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,behavior: null == behavior ? _self.behavior : behavior // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,vehicle: null == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,interval: null == interval ? _self.interval : interval // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CoreRule {

 int get index; String get type;@JsonKey(name: 'rule-type') String get ruleType; String get payload;@JsonKey(name: 'rule-payload') String get rulePayload; String get target; bool get disabled; bool get managed;@JsonKey(name: 'rule-set') RuleSetView? get ruleSet;
/// Create a copy of CoreRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreRuleCopyWith<CoreRule> get copyWith => _$CoreRuleCopyWithImpl<CoreRule>(this as CoreRule, _$identity);

  /// Serializes this CoreRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CoreRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreRule&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.ruleType, _this.ruleType) || other.ruleType == _this.ruleType)&&(identical(other.payload, _this.payload) || other.payload == _this.payload)&&(identical(other.rulePayload, _this.rulePayload) || other.rulePayload == _this.rulePayload)&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.disabled, _this.disabled) || other.disabled == _this.disabled)&&(identical(other.managed, _this.managed) || other.managed == _this.managed)&&(identical(other.ruleSet, _this.ruleSet) || other.ruleSet == _this.ruleSet));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CoreRule;
  return Object.hash(runtimeType,_this.index,_this.type,_this.ruleType,_this.payload,_this.rulePayload,_this.target,_this.disabled,_this.managed,_this.ruleSet);
}

@override
String toString() {
  final _this = this as CoreRule;
  return 'CoreRule(index: ${_this.index}, type: ${_this.type}, ruleType: ${_this.ruleType}, payload: ${_this.payload}, rulePayload: ${_this.rulePayload}, target: ${_this.target}, disabled: ${_this.disabled}, managed: ${_this.managed}, ruleSet: ${_this.ruleSet})';
}


}

/// @nodoc
abstract mixin class $CoreRuleCopyWith<$Res>  {
  factory $CoreRuleCopyWith(CoreRule value, $Res Function(CoreRule) _then) = _$CoreRuleCopyWithImpl;
@useResult
$Res call({
 int index, String type,@JsonKey(name: 'rule-type') String ruleType, String payload,@JsonKey(name: 'rule-payload') String rulePayload, String target, bool disabled, bool managed,@JsonKey(name: 'rule-set') RuleSetView? ruleSet
});


$RuleSetViewCopyWith<$Res>? get ruleSet;

}
/// @nodoc
class _$CoreRuleCopyWithImpl<$Res>
    implements $CoreRuleCopyWith<$Res> {
  _$CoreRuleCopyWithImpl(this._self, this._then);

  final CoreRule _self;
  final $Res Function(CoreRule) _then;

/// Create a copy of CoreRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? type = null,Object? ruleType = null,Object? payload = null,Object? rulePayload = null,Object? target = null,Object? disabled = null,Object? managed = null,Object? ruleSet = freezed,}) {
  return _then(CoreRule(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,ruleType: null == ruleType ? _self.ruleType : ruleType // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as String,rulePayload: null == rulePayload ? _self.rulePayload : rulePayload // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,managed: null == managed ? _self.managed : managed // ignore: cast_nullable_to_non_nullable
as bool,ruleSet: freezed == ruleSet ? _self.ruleSet : ruleSet // ignore: cast_nullable_to_non_nullable
as RuleSetView?,
  ));
}
/// Create a copy of CoreRule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RuleSetViewCopyWith<$Res>? get ruleSet {
    if (_self.ruleSet == null) {
    return null;
  }

  return $RuleSetViewCopyWith<$Res>(_self.ruleSet!, (value) {
    return _then(_self.copyWith(ruleSet: value));
  });
}
}


/// Adds pattern-matching-related methods to [CoreRule].
extension CoreRulePatterns on CoreRule {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CoreRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CoreRule() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CoreRule value)  $default,){
final _that = this;
switch (_that) {
case _CoreRule():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CoreRule value)?  $default,){
final _that = this;
switch (_that) {
case _CoreRule() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String type, @JsonKey(name: 'rule-type')  String ruleType,  String payload, @JsonKey(name: 'rule-payload')  String rulePayload,  String target,  bool disabled,  bool managed, @JsonKey(name: 'rule-set')  RuleSetView? ruleSet)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CoreRule() when $default != null:
return $default(_that.index,_that.type,_that.ruleType,_that.payload,_that.rulePayload,_that.target,_that.disabled,_that.managed,_that.ruleSet);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String type, @JsonKey(name: 'rule-type')  String ruleType,  String payload, @JsonKey(name: 'rule-payload')  String rulePayload,  String target,  bool disabled,  bool managed, @JsonKey(name: 'rule-set')  RuleSetView? ruleSet)  $default,) {final _that = this;
switch (_that) {
case _CoreRule():
return $default(_that.index,_that.type,_that.ruleType,_that.payload,_that.rulePayload,_that.target,_that.disabled,_that.managed,_that.ruleSet);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String type, @JsonKey(name: 'rule-type')  String ruleType,  String payload, @JsonKey(name: 'rule-payload')  String rulePayload,  String target,  bool disabled,  bool managed, @JsonKey(name: 'rule-set')  RuleSetView? ruleSet)?  $default,) {final _that = this;
switch (_that) {
case _CoreRule() when $default != null:
return $default(_that.index,_that.type,_that.ruleType,_that.payload,_that.rulePayload,_that.target,_that.disabled,_that.managed,_that.ruleSet);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CoreRule extends CoreRule {
  const _CoreRule({this.index = 0, this.type = '', @JsonKey(name: 'rule-type') this.ruleType = '', this.payload = '', @JsonKey(name: 'rule-payload') this.rulePayload = '', this.target = '', this.disabled = false, this.managed = false, @JsonKey(name: 'rule-set') this.ruleSet}): super._();
  factory _CoreRule.fromJson(Map<String, dynamic> json) => _$CoreRuleFromJson(json);

@override@JsonKey() final  int index;
@override@JsonKey() final  String type;
@override@JsonKey(name: 'rule-type') final  String ruleType;
@override@JsonKey() final  String payload;
@override@JsonKey(name: 'rule-payload') final  String rulePayload;
@override@JsonKey() final  String target;
@override@JsonKey() final  bool disabled;
@override@JsonKey() final  bool managed;
@override@JsonKey(name: 'rule-set') final  RuleSetView? ruleSet;

/// Create a copy of CoreRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CoreRuleCopyWith<_CoreRule> get copyWith => __$CoreRuleCopyWithImpl<_CoreRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CoreRuleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CoreRule&&(identical(other.index, index) || other.index == index)&&(identical(other.type, type) || other.type == type)&&(identical(other.ruleType, ruleType) || other.ruleType == ruleType)&&(identical(other.payload, payload) || other.payload == payload)&&(identical(other.rulePayload, rulePayload) || other.rulePayload == rulePayload)&&(identical(other.target, target) || other.target == target)&&(identical(other.disabled, disabled) || other.disabled == disabled)&&(identical(other.managed, managed) || other.managed == managed)&&(identical(other.ruleSet, ruleSet) || other.ruleSet == ruleSet));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,index,type,ruleType,payload,rulePayload,target,disabled,managed,ruleSet);
}

@override
String toString() {
    return 'CoreRule(index: $index, type: $type, ruleType: $ruleType, payload: $payload, rulePayload: $rulePayload, target: $target, disabled: $disabled, managed: $managed, ruleSet: $ruleSet)';
}


}

/// @nodoc
abstract mixin class _$CoreRuleCopyWith<$Res> implements $CoreRuleCopyWith<$Res> {
  factory _$CoreRuleCopyWith(_CoreRule value, $Res Function(_CoreRule) _then) = __$CoreRuleCopyWithImpl;
@override @useResult
$Res call({
 int index, String type,@JsonKey(name: 'rule-type') String ruleType, String payload,@JsonKey(name: 'rule-payload') String rulePayload, String target, bool disabled, bool managed,@JsonKey(name: 'rule-set') RuleSetView? ruleSet
});


@override $RuleSetViewCopyWith<$Res>? get ruleSet;

}
/// @nodoc
class __$CoreRuleCopyWithImpl<$Res>
    implements _$CoreRuleCopyWith<$Res> {
  __$CoreRuleCopyWithImpl(this._self, this._then);

  final _CoreRule _self;
  final $Res Function(_CoreRule) _then;

/// Create a copy of CoreRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? type = null,Object? ruleType = null,Object? payload = null,Object? rulePayload = null,Object? target = null,Object? disabled = null,Object? managed = null,Object? ruleSet = freezed,}) {
  return _then(_CoreRule(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,ruleType: null == ruleType ? _self.ruleType : ruleType // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as String,rulePayload: null == rulePayload ? _self.rulePayload : rulePayload // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,managed: null == managed ? _self.managed : managed // ignore: cast_nullable_to_non_nullable
as bool,ruleSet: freezed == ruleSet ? _self.ruleSet : ruleSet // ignore: cast_nullable_to_non_nullable
as RuleSetView?,
  ));
}

/// Create a copy of CoreRule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RuleSetViewCopyWith<$Res>? get ruleSet {
    if (_self.ruleSet == null) {
    return null;
  }

  return $RuleSetViewCopyWith<$Res>(_self.ruleSet!, (value) {
    return _then(_self.copyWith(ruleSet: value));
  });
}
}


/// @nodoc
mixin _$RuleList {

@JsonKey(name: 'core-epoch') int get coreEpoch; String get mode;@JsonKey(name: 'managed-prefix') int get managedPrefix; int get total; List<CoreRule> get rules; List<int> get filtered;@JsonKey(name: 'set-matches') Map<String, int> get setMatches;
/// Create a copy of RuleList
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleListCopyWith<RuleList> get copyWith => _$RuleListCopyWithImpl<RuleList>(this as RuleList, _$identity);

  /// Serializes this RuleList to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RuleList;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleList&&(identical(other.coreEpoch, _this.coreEpoch) || other.coreEpoch == _this.coreEpoch)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.managedPrefix, _this.managedPrefix) || other.managedPrefix == _this.managedPrefix)&&(identical(other.total, _this.total) || other.total == _this.total)&&const DeepCollectionEquality().equals(other.rules, _this.rules)&&const DeepCollectionEquality().equals(other.filtered, _this.filtered)&&const DeepCollectionEquality().equals(other.setMatches, _this.setMatches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RuleList;
  return Object.hash(runtimeType,_this.coreEpoch,_this.mode,_this.managedPrefix,_this.total,const DeepCollectionEquality().hash(_this.rules),const DeepCollectionEquality().hash(_this.filtered),const DeepCollectionEquality().hash(_this.setMatches));
}

@override
String toString() {
  final _this = this as RuleList;
  return 'RuleList(coreEpoch: ${_this.coreEpoch}, mode: ${_this.mode}, managedPrefix: ${_this.managedPrefix}, total: ${_this.total}, rules: ${_this.rules}, filtered: ${_this.filtered}, setMatches: ${_this.setMatches})';
}


}

/// @nodoc
abstract mixin class $RuleListCopyWith<$Res>  {
  factory $RuleListCopyWith(RuleList value, $Res Function(RuleList) _then) = _$RuleListCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'core-epoch') int coreEpoch, String mode,@JsonKey(name: 'managed-prefix') int managedPrefix, int total, List<CoreRule> rules, List<int> filtered,@JsonKey(name: 'set-matches') Map<String, int> setMatches
});




}
/// @nodoc
class _$RuleListCopyWithImpl<$Res>
    implements $RuleListCopyWith<$Res> {
  _$RuleListCopyWithImpl(this._self, this._then);

  final RuleList _self;
  final $Res Function(RuleList) _then;

/// Create a copy of RuleList
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? coreEpoch = null,Object? mode = null,Object? managedPrefix = null,Object? total = null,Object? rules = null,Object? filtered = null,Object? setMatches = null,}) {
  return _then(RuleList(
coreEpoch: null == coreEpoch ? _self.coreEpoch : coreEpoch // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,managedPrefix: null == managedPrefix ? _self.managedPrefix : managedPrefix // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as List<CoreRule>,filtered: null == filtered ? _self.filtered : filtered // ignore: cast_nullable_to_non_nullable
as List<int>,setMatches: null == setMatches ? _self.setMatches : setMatches // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [RuleList].
extension RuleListPatterns on RuleList {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleList value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleList() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleList value)  $default,){
final _that = this;
switch (_that) {
case _RuleList():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleList value)?  $default,){
final _that = this;
switch (_that) {
case _RuleList() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'core-epoch')  int coreEpoch,  String mode, @JsonKey(name: 'managed-prefix')  int managedPrefix,  int total,  List<CoreRule> rules,  List<int> filtered, @JsonKey(name: 'set-matches')  Map<String, int> setMatches)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleList() when $default != null:
return $default(_that.coreEpoch,_that.mode,_that.managedPrefix,_that.total,_that.rules,_that.filtered,_that.setMatches);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'core-epoch')  int coreEpoch,  String mode, @JsonKey(name: 'managed-prefix')  int managedPrefix,  int total,  List<CoreRule> rules,  List<int> filtered, @JsonKey(name: 'set-matches')  Map<String, int> setMatches)  $default,) {final _that = this;
switch (_that) {
case _RuleList():
return $default(_that.coreEpoch,_that.mode,_that.managedPrefix,_that.total,_that.rules,_that.filtered,_that.setMatches);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'core-epoch')  int coreEpoch,  String mode, @JsonKey(name: 'managed-prefix')  int managedPrefix,  int total,  List<CoreRule> rules,  List<int> filtered, @JsonKey(name: 'set-matches')  Map<String, int> setMatches)?  $default,) {final _that = this;
switch (_that) {
case _RuleList() when $default != null:
return $default(_that.coreEpoch,_that.mode,_that.managedPrefix,_that.total,_that.rules,_that.filtered,_that.setMatches);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuleList implements RuleList {
  const _RuleList({@JsonKey(name: 'core-epoch') this.coreEpoch = 0, this.mode = '', @JsonKey(name: 'managed-prefix') this.managedPrefix = 0, this.total = 0,  List<CoreRule> rules = const [],  List<int> filtered = const [], @JsonKey(name: 'set-matches')  Map<String, int> setMatches = const {}}): _rules = rules,_filtered = filtered,_setMatches = setMatches;
  factory _RuleList.fromJson(Map<String, dynamic> json) => _$RuleListFromJson(json);

@override@JsonKey(name: 'core-epoch') final  int coreEpoch;
@override@JsonKey() final  String mode;
@override@JsonKey(name: 'managed-prefix') final  int managedPrefix;
@override@JsonKey() final  int total;
 final  List<CoreRule> _rules;
@override@JsonKey() List<CoreRule> get rules {
  if (_rules is EqualUnmodifiableListView) return _rules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rules);
}

 final  List<int> _filtered;
@override@JsonKey() List<int> get filtered {
  if (_filtered is EqualUnmodifiableListView) return _filtered;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_filtered);
}

 final  Map<String, int> _setMatches;
@override@JsonKey(name: 'set-matches') Map<String, int> get setMatches {
  if (_setMatches is EqualUnmodifiableMapView) return _setMatches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_setMatches);
}


/// Create a copy of RuleList
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleListCopyWith<_RuleList> get copyWith => __$RuleListCopyWithImpl<_RuleList>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuleListToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleList&&(identical(other.coreEpoch, coreEpoch) || other.coreEpoch == coreEpoch)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.managedPrefix, managedPrefix) || other.managedPrefix == managedPrefix)&&(identical(other.total, total) || other.total == total)&&const DeepCollectionEquality().equals(other.rules, _rules)&&const DeepCollectionEquality().equals(other.filtered, _filtered)&&const DeepCollectionEquality().equals(other.setMatches, _setMatches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,coreEpoch,mode,managedPrefix,total,const DeepCollectionEquality().hash(_rules),const DeepCollectionEquality().hash(_filtered),const DeepCollectionEquality().hash(_setMatches));
}

@override
String toString() {
    return 'RuleList(coreEpoch: $coreEpoch, mode: $mode, managedPrefix: $managedPrefix, total: $total, rules: $rules, filtered: $filtered, setMatches: $setMatches)';
}


}

/// @nodoc
abstract mixin class _$RuleListCopyWith<$Res> implements $RuleListCopyWith<$Res> {
  factory _$RuleListCopyWith(_RuleList value, $Res Function(_RuleList) _then) = __$RuleListCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'core-epoch') int coreEpoch, String mode,@JsonKey(name: 'managed-prefix') int managedPrefix, int total, List<CoreRule> rules, List<int> filtered,@JsonKey(name: 'set-matches') Map<String, int> setMatches
});




}
/// @nodoc
class __$RuleListCopyWithImpl<$Res>
    implements _$RuleListCopyWith<$Res> {
  __$RuleListCopyWithImpl(this._self, this._then);

  final _RuleList _self;
  final $Res Function(_RuleList) _then;

/// Create a copy of RuleList
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? coreEpoch = null,Object? mode = null,Object? managedPrefix = null,Object? total = null,Object? rules = null,Object? filtered = null,Object? setMatches = null,}) {
  return _then(_RuleList(
coreEpoch: null == coreEpoch ? _self.coreEpoch : coreEpoch // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,managedPrefix: null == managedPrefix ? _self.managedPrefix : managedPrefix // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,rules: null == rules ? _self._rules : rules // ignore: cast_nullable_to_non_nullable
as List<CoreRule>,filtered: null == filtered ? _self._filtered : filtered // ignore: cast_nullable_to_non_nullable
as List<int>,setMatches: null == setMatches ? _self._setMatches : setMatches // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}


}


/// @nodoc
mixin _$RuleSetEntries {

@JsonKey(name: 'core-epoch') int get coreEpoch; String get name; String get behavior; int get total; int get matched; int get offset; List<String> get entries;
/// Create a copy of RuleSetEntries
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleSetEntriesCopyWith<RuleSetEntries> get copyWith => _$RuleSetEntriesCopyWithImpl<RuleSetEntries>(this as RuleSetEntries, _$identity);

  /// Serializes this RuleSetEntries to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RuleSetEntries;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleSetEntries&&(identical(other.coreEpoch, _this.coreEpoch) || other.coreEpoch == _this.coreEpoch)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.behavior, _this.behavior) || other.behavior == _this.behavior)&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.matched, _this.matched) || other.matched == _this.matched)&&(identical(other.offset, _this.offset) || other.offset == _this.offset)&&const DeepCollectionEquality().equals(other.entries, _this.entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RuleSetEntries;
  return Object.hash(runtimeType,_this.coreEpoch,_this.name,_this.behavior,_this.total,_this.matched,_this.offset,const DeepCollectionEquality().hash(_this.entries));
}

@override
String toString() {
  final _this = this as RuleSetEntries;
  return 'RuleSetEntries(coreEpoch: ${_this.coreEpoch}, name: ${_this.name}, behavior: ${_this.behavior}, total: ${_this.total}, matched: ${_this.matched}, offset: ${_this.offset}, entries: ${_this.entries})';
}


}

/// @nodoc
abstract mixin class $RuleSetEntriesCopyWith<$Res>  {
  factory $RuleSetEntriesCopyWith(RuleSetEntries value, $Res Function(RuleSetEntries) _then) = _$RuleSetEntriesCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'core-epoch') int coreEpoch, String name, String behavior, int total, int matched, int offset, List<String> entries
});




}
/// @nodoc
class _$RuleSetEntriesCopyWithImpl<$Res>
    implements $RuleSetEntriesCopyWith<$Res> {
  _$RuleSetEntriesCopyWithImpl(this._self, this._then);

  final RuleSetEntries _self;
  final $Res Function(RuleSetEntries) _then;

/// Create a copy of RuleSetEntries
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? coreEpoch = null,Object? name = null,Object? behavior = null,Object? total = null,Object? matched = null,Object? offset = null,Object? entries = null,}) {
  return _then(RuleSetEntries(
coreEpoch: null == coreEpoch ? _self.coreEpoch : coreEpoch // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,behavior: null == behavior ? _self.behavior : behavior // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,matched: null == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [RuleSetEntries].
extension RuleSetEntriesPatterns on RuleSetEntries {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleSetEntries value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleSetEntries() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleSetEntries value)  $default,){
final _that = this;
switch (_that) {
case _RuleSetEntries():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleSetEntries value)?  $default,){
final _that = this;
switch (_that) {
case _RuleSetEntries() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'core-epoch')  int coreEpoch,  String name,  String behavior,  int total,  int matched,  int offset,  List<String> entries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleSetEntries() when $default != null:
return $default(_that.coreEpoch,_that.name,_that.behavior,_that.total,_that.matched,_that.offset,_that.entries);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'core-epoch')  int coreEpoch,  String name,  String behavior,  int total,  int matched,  int offset,  List<String> entries)  $default,) {final _that = this;
switch (_that) {
case _RuleSetEntries():
return $default(_that.coreEpoch,_that.name,_that.behavior,_that.total,_that.matched,_that.offset,_that.entries);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'core-epoch')  int coreEpoch,  String name,  String behavior,  int total,  int matched,  int offset,  List<String> entries)?  $default,) {final _that = this;
switch (_that) {
case _RuleSetEntries() when $default != null:
return $default(_that.coreEpoch,_that.name,_that.behavior,_that.total,_that.matched,_that.offset,_that.entries);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuleSetEntries implements RuleSetEntries {
  const _RuleSetEntries({@JsonKey(name: 'core-epoch') this.coreEpoch = 0, this.name = '', this.behavior = '', this.total = 0, this.matched = 0, this.offset = 0,  List<String> entries = const []}): _entries = entries;
  factory _RuleSetEntries.fromJson(Map<String, dynamic> json) => _$RuleSetEntriesFromJson(json);

@override@JsonKey(name: 'core-epoch') final  int coreEpoch;
@override@JsonKey() final  String name;
@override@JsonKey() final  String behavior;
@override@JsonKey() final  int total;
@override@JsonKey() final  int matched;
@override@JsonKey() final  int offset;
 final  List<String> _entries;
@override@JsonKey() List<String> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of RuleSetEntries
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleSetEntriesCopyWith<_RuleSetEntries> get copyWith => __$RuleSetEntriesCopyWithImpl<_RuleSetEntries>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuleSetEntriesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleSetEntries&&(identical(other.coreEpoch, coreEpoch) || other.coreEpoch == coreEpoch)&&(identical(other.name, name) || other.name == name)&&(identical(other.behavior, behavior) || other.behavior == behavior)&&(identical(other.total, total) || other.total == total)&&(identical(other.matched, matched) || other.matched == matched)&&(identical(other.offset, offset) || other.offset == offset)&&const DeepCollectionEquality().equals(other.entries, _entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,coreEpoch,name,behavior,total,matched,offset,const DeepCollectionEquality().hash(_entries));
}

@override
String toString() {
    return 'RuleSetEntries(coreEpoch: $coreEpoch, name: $name, behavior: $behavior, total: $total, matched: $matched, offset: $offset, entries: $entries)';
}


}

/// @nodoc
abstract mixin class _$RuleSetEntriesCopyWith<$Res> implements $RuleSetEntriesCopyWith<$Res> {
  factory _$RuleSetEntriesCopyWith(_RuleSetEntries value, $Res Function(_RuleSetEntries) _then) = __$RuleSetEntriesCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'core-epoch') int coreEpoch, String name, String behavior, int total, int matched, int offset, List<String> entries
});




}
/// @nodoc
class __$RuleSetEntriesCopyWithImpl<$Res>
    implements _$RuleSetEntriesCopyWith<$Res> {
  __$RuleSetEntriesCopyWithImpl(this._self, this._then);

  final _RuleSetEntries _self;
  final $Res Function(_RuleSetEntries) _then;

/// Create a copy of RuleSetEntries
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? coreEpoch = null,Object? name = null,Object? behavior = null,Object? total = null,Object? matched = null,Object? offset = null,Object? entries = null,}) {
  return _then(_RuleSetEntries(
coreEpoch: null == coreEpoch ? _self.coreEpoch : coreEpoch // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,behavior: null == behavior ? _self.behavior : behavior // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,matched: null == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$RuleLookupParams {

 String get host;@JsonKey(includeIfNull: false) int? get port;@JsonKey(includeIfNull: false) String? get network; bool get resolve;
/// Create a copy of RuleLookupParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleLookupParamsCopyWith<RuleLookupParams> get copyWith => _$RuleLookupParamsCopyWithImpl<RuleLookupParams>(this as RuleLookupParams, _$identity);

  /// Serializes this RuleLookupParams to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RuleLookupParams;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleLookupParams&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.network, _this.network) || other.network == _this.network)&&(identical(other.resolve, _this.resolve) || other.resolve == _this.resolve));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RuleLookupParams;
  return Object.hash(runtimeType,_this.host,_this.port,_this.network,_this.resolve);
}

@override
String toString() {
  final _this = this as RuleLookupParams;
  return 'RuleLookupParams(host: ${_this.host}, port: ${_this.port}, network: ${_this.network}, resolve: ${_this.resolve})';
}


}

/// @nodoc
abstract mixin class $RuleLookupParamsCopyWith<$Res>  {
  factory $RuleLookupParamsCopyWith(RuleLookupParams value, $Res Function(RuleLookupParams) _then) = _$RuleLookupParamsCopyWithImpl;
@useResult
$Res call({
 String host,@JsonKey(includeIfNull: false) int? port,@JsonKey(includeIfNull: false) String? network, bool resolve
});




}
/// @nodoc
class _$RuleLookupParamsCopyWithImpl<$Res>
    implements $RuleLookupParamsCopyWith<$Res> {
  _$RuleLookupParamsCopyWithImpl(this._self, this._then);

  final RuleLookupParams _self;
  final $Res Function(RuleLookupParams) _then;

/// Create a copy of RuleLookupParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? host = null,Object? port = freezed,Object? network = freezed,Object? resolve = null,}) {
  return _then(RuleLookupParams(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,network: freezed == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as String?,resolve: null == resolve ? _self.resolve : resolve // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RuleLookupParams].
extension RuleLookupParamsPatterns on RuleLookupParams {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleLookupParams value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleLookupParams() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleLookupParams value)  $default,){
final _that = this;
switch (_that) {
case _RuleLookupParams():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleLookupParams value)?  $default,){
final _that = this;
switch (_that) {
case _RuleLookupParams() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String host, @JsonKey(includeIfNull: false)  int? port, @JsonKey(includeIfNull: false)  String? network,  bool resolve)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleLookupParams() when $default != null:
return $default(_that.host,_that.port,_that.network,_that.resolve);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String host, @JsonKey(includeIfNull: false)  int? port, @JsonKey(includeIfNull: false)  String? network,  bool resolve)  $default,) {final _that = this;
switch (_that) {
case _RuleLookupParams():
return $default(_that.host,_that.port,_that.network,_that.resolve);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String host, @JsonKey(includeIfNull: false)  int? port, @JsonKey(includeIfNull: false)  String? network,  bool resolve)?  $default,) {final _that = this;
switch (_that) {
case _RuleLookupParams() when $default != null:
return $default(_that.host,_that.port,_that.network,_that.resolve);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuleLookupParams implements RuleLookupParams {
  const _RuleLookupParams({required this.host, @JsonKey(includeIfNull: false) this.port, @JsonKey(includeIfNull: false) this.network, this.resolve = true});
  factory _RuleLookupParams.fromJson(Map<String, dynamic> json) => _$RuleLookupParamsFromJson(json);

@override final  String host;
@override@JsonKey(includeIfNull: false) final  int? port;
@override@JsonKey(includeIfNull: false) final  String? network;
@override@JsonKey() final  bool resolve;

/// Create a copy of RuleLookupParams
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleLookupParamsCopyWith<_RuleLookupParams> get copyWith => __$RuleLookupParamsCopyWithImpl<_RuleLookupParams>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuleLookupParamsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleLookupParams&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.network, network) || other.network == network)&&(identical(other.resolve, resolve) || other.resolve == resolve));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,host,port,network,resolve);
}

@override
String toString() {
    return 'RuleLookupParams(host: $host, port: $port, network: $network, resolve: $resolve)';
}


}

/// @nodoc
abstract mixin class _$RuleLookupParamsCopyWith<$Res> implements $RuleLookupParamsCopyWith<$Res> {
  factory _$RuleLookupParamsCopyWith(_RuleLookupParams value, $Res Function(_RuleLookupParams) _then) = __$RuleLookupParamsCopyWithImpl;
@override @useResult
$Res call({
 String host,@JsonKey(includeIfNull: false) int? port,@JsonKey(includeIfNull: false) String? network, bool resolve
});




}
/// @nodoc
class __$RuleLookupParamsCopyWithImpl<$Res>
    implements _$RuleLookupParamsCopyWith<$Res> {
  __$RuleLookupParamsCopyWithImpl(this._self, this._then);

  final _RuleLookupParams _self;
  final $Res Function(_RuleLookupParams) _then;

/// Create a copy of RuleLookupParams
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? host = null,Object? port = freezed,Object? network = freezed,Object? resolve = null,}) {
  return _then(_RuleLookupParams(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: freezed == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int?,network: freezed == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as String?,resolve: null == resolve ? _self.resolve : resolve // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ChainHop {

 String get name; String get type;
/// Create a copy of ChainHop
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChainHopCopyWith<ChainHop> get copyWith => _$ChainHopCopyWithImpl<ChainHop>(this as ChainHop, _$identity);

  /// Serializes this ChainHop to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ChainHop;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChainHop&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.type, _this.type) || other.type == _this.type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ChainHop;
  return Object.hash(runtimeType,_this.name,_this.type);
}

@override
String toString() {
  final _this = this as ChainHop;
  return 'ChainHop(name: ${_this.name}, type: ${_this.type})';
}


}

/// @nodoc
abstract mixin class $ChainHopCopyWith<$Res>  {
  factory $ChainHopCopyWith(ChainHop value, $Res Function(ChainHop) _then) = _$ChainHopCopyWithImpl;
@useResult
$Res call({
 String name, String type
});




}
/// @nodoc
class _$ChainHopCopyWithImpl<$Res>
    implements $ChainHopCopyWith<$Res> {
  _$ChainHopCopyWithImpl(this._self, this._then);

  final ChainHop _self;
  final $Res Function(ChainHop) _then;

/// Create a copy of ChainHop
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? type = null,}) {
  return _then(ChainHop(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChainHop].
extension ChainHopPatterns on ChainHop {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChainHop value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChainHop() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChainHop value)  $default,){
final _that = this;
switch (_that) {
case _ChainHop():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChainHop value)?  $default,){
final _that = this;
switch (_that) {
case _ChainHop() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String type)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChainHop() when $default != null:
return $default(_that.name,_that.type);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String type)  $default,) {final _that = this;
switch (_that) {
case _ChainHop():
return $default(_that.name,_that.type);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String type)?  $default,) {final _that = this;
switch (_that) {
case _ChainHop() when $default != null:
return $default(_that.name,_that.type);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChainHop implements ChainHop {
  const _ChainHop({this.name = '', this.type = ''});
  factory _ChainHop.fromJson(Map<String, dynamic> json) => _$ChainHopFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String type;

/// Create a copy of ChainHop
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChainHopCopyWith<_ChainHop> get copyWith => __$ChainHopCopyWithImpl<_ChainHop>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChainHopToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChainHop&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,type);
}

@override
String toString() {
    return 'ChainHop(name: $name, type: $type)';
}


}

/// @nodoc
abstract mixin class _$ChainHopCopyWith<$Res> implements $ChainHopCopyWith<$Res> {
  factory _$ChainHopCopyWith(_ChainHop value, $Res Function(_ChainHop) _then) = __$ChainHopCopyWithImpl;
@override @useResult
$Res call({
 String name, String type
});




}
/// @nodoc
class __$ChainHopCopyWithImpl<$Res>
    implements _$ChainHopCopyWith<$Res> {
  __$ChainHopCopyWithImpl(this._self, this._then);

  final _ChainHop _self;
  final $Res Function(_ChainHop) _then;

/// Create a copy of ChainHop
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? type = null,}) {
  return _then(_ChainHop(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RuleHit {

 int get index; String get type;@JsonKey(name: 'rule-type') String get ruleType; String get payload;@JsonKey(name: 'rule-payload') String get rulePayload; String get target; bool get disabled; bool get managed;@JsonKey(name: 'rule-set') RuleSetView? get ruleSet;@JsonKey(unknownEnumValue: RuleHitStatus.uncertain) RuleHitStatus get status; String get reason; String get detail; String get entry;
/// Create a copy of RuleHit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleHitCopyWith<RuleHit> get copyWith => _$RuleHitCopyWithImpl<RuleHit>(this as RuleHit, _$identity);

  /// Serializes this RuleHit to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RuleHit;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleHit&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.ruleType, _this.ruleType) || other.ruleType == _this.ruleType)&&(identical(other.payload, _this.payload) || other.payload == _this.payload)&&(identical(other.rulePayload, _this.rulePayload) || other.rulePayload == _this.rulePayload)&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.disabled, _this.disabled) || other.disabled == _this.disabled)&&(identical(other.managed, _this.managed) || other.managed == _this.managed)&&(identical(other.ruleSet, _this.ruleSet) || other.ruleSet == _this.ruleSet)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.reason, _this.reason) || other.reason == _this.reason)&&(identical(other.detail, _this.detail) || other.detail == _this.detail)&&(identical(other.entry, _this.entry) || other.entry == _this.entry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RuleHit;
  return Object.hash(runtimeType,_this.index,_this.type,_this.ruleType,_this.payload,_this.rulePayload,_this.target,_this.disabled,_this.managed,_this.ruleSet,_this.status,_this.reason,_this.detail,_this.entry);
}

@override
String toString() {
  final _this = this as RuleHit;
  return 'RuleHit(index: ${_this.index}, type: ${_this.type}, ruleType: ${_this.ruleType}, payload: ${_this.payload}, rulePayload: ${_this.rulePayload}, target: ${_this.target}, disabled: ${_this.disabled}, managed: ${_this.managed}, ruleSet: ${_this.ruleSet}, status: ${_this.status}, reason: ${_this.reason}, detail: ${_this.detail}, entry: ${_this.entry})';
}


}

/// @nodoc
abstract mixin class $RuleHitCopyWith<$Res>  {
  factory $RuleHitCopyWith(RuleHit value, $Res Function(RuleHit) _then) = _$RuleHitCopyWithImpl;
@useResult
$Res call({
 int index, String type,@JsonKey(name: 'rule-type') String ruleType, String payload,@JsonKey(name: 'rule-payload') String rulePayload, String target, bool disabled, bool managed,@JsonKey(name: 'rule-set') RuleSetView? ruleSet,@JsonKey(unknownEnumValue: RuleHitStatus.uncertain) RuleHitStatus status, String reason, String detail, String entry
});


$RuleSetViewCopyWith<$Res>? get ruleSet;

}
/// @nodoc
class _$RuleHitCopyWithImpl<$Res>
    implements $RuleHitCopyWith<$Res> {
  _$RuleHitCopyWithImpl(this._self, this._then);

  final RuleHit _self;
  final $Res Function(RuleHit) _then;

/// Create a copy of RuleHit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? type = null,Object? ruleType = null,Object? payload = null,Object? rulePayload = null,Object? target = null,Object? disabled = null,Object? managed = null,Object? ruleSet = freezed,Object? status = null,Object? reason = null,Object? detail = null,Object? entry = null,}) {
  return _then(RuleHit(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,ruleType: null == ruleType ? _self.ruleType : ruleType // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as String,rulePayload: null == rulePayload ? _self.rulePayload : rulePayload // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,managed: null == managed ? _self.managed : managed // ignore: cast_nullable_to_non_nullable
as bool,ruleSet: freezed == ruleSet ? _self.ruleSet : ruleSet // ignore: cast_nullable_to_non_nullable
as RuleSetView?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RuleHitStatus,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of RuleHit
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RuleSetViewCopyWith<$Res>? get ruleSet {
    if (_self.ruleSet == null) {
    return null;
  }

  return $RuleSetViewCopyWith<$Res>(_self.ruleSet!, (value) {
    return _then(_self.copyWith(ruleSet: value));
  });
}
}


/// Adds pattern-matching-related methods to [RuleHit].
extension RuleHitPatterns on RuleHit {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleHit value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleHit() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleHit value)  $default,){
final _that = this;
switch (_that) {
case _RuleHit():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleHit value)?  $default,){
final _that = this;
switch (_that) {
case _RuleHit() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String type, @JsonKey(name: 'rule-type')  String ruleType,  String payload, @JsonKey(name: 'rule-payload')  String rulePayload,  String target,  bool disabled,  bool managed, @JsonKey(name: 'rule-set')  RuleSetView? ruleSet, @JsonKey(unknownEnumValue: RuleHitStatus.uncertain)  RuleHitStatus status,  String reason,  String detail,  String entry)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleHit() when $default != null:
return $default(_that.index,_that.type,_that.ruleType,_that.payload,_that.rulePayload,_that.target,_that.disabled,_that.managed,_that.ruleSet,_that.status,_that.reason,_that.detail,_that.entry);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String type, @JsonKey(name: 'rule-type')  String ruleType,  String payload, @JsonKey(name: 'rule-payload')  String rulePayload,  String target,  bool disabled,  bool managed, @JsonKey(name: 'rule-set')  RuleSetView? ruleSet, @JsonKey(unknownEnumValue: RuleHitStatus.uncertain)  RuleHitStatus status,  String reason,  String detail,  String entry)  $default,) {final _that = this;
switch (_that) {
case _RuleHit():
return $default(_that.index,_that.type,_that.ruleType,_that.payload,_that.rulePayload,_that.target,_that.disabled,_that.managed,_that.ruleSet,_that.status,_that.reason,_that.detail,_that.entry);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String type, @JsonKey(name: 'rule-type')  String ruleType,  String payload, @JsonKey(name: 'rule-payload')  String rulePayload,  String target,  bool disabled,  bool managed, @JsonKey(name: 'rule-set')  RuleSetView? ruleSet, @JsonKey(unknownEnumValue: RuleHitStatus.uncertain)  RuleHitStatus status,  String reason,  String detail,  String entry)?  $default,) {final _that = this;
switch (_that) {
case _RuleHit() when $default != null:
return $default(_that.index,_that.type,_that.ruleType,_that.payload,_that.rulePayload,_that.target,_that.disabled,_that.managed,_that.ruleSet,_that.status,_that.reason,_that.detail,_that.entry);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuleHit extends RuleHit {
  const _RuleHit({this.index = 0, this.type = '', @JsonKey(name: 'rule-type') this.ruleType = '', this.payload = '', @JsonKey(name: 'rule-payload') this.rulePayload = '', this.target = '', this.disabled = false, this.managed = false, @JsonKey(name: 'rule-set') this.ruleSet, @JsonKey(unknownEnumValue: RuleHitStatus.uncertain) this.status = RuleHitStatus.uncertain, this.reason = '', this.detail = '', this.entry = ''}): super._();
  factory _RuleHit.fromJson(Map<String, dynamic> json) => _$RuleHitFromJson(json);

@override@JsonKey() final  int index;
@override@JsonKey() final  String type;
@override@JsonKey(name: 'rule-type') final  String ruleType;
@override@JsonKey() final  String payload;
@override@JsonKey(name: 'rule-payload') final  String rulePayload;
@override@JsonKey() final  String target;
@override@JsonKey() final  bool disabled;
@override@JsonKey() final  bool managed;
@override@JsonKey(name: 'rule-set') final  RuleSetView? ruleSet;
@override@JsonKey(unknownEnumValue: RuleHitStatus.uncertain) final  RuleHitStatus status;
@override@JsonKey() final  String reason;
@override@JsonKey() final  String detail;
@override@JsonKey() final  String entry;

/// Create a copy of RuleHit
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleHitCopyWith<_RuleHit> get copyWith => __$RuleHitCopyWithImpl<_RuleHit>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuleHitToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleHit&&(identical(other.index, index) || other.index == index)&&(identical(other.type, type) || other.type == type)&&(identical(other.ruleType, ruleType) || other.ruleType == ruleType)&&(identical(other.payload, payload) || other.payload == payload)&&(identical(other.rulePayload, rulePayload) || other.rulePayload == rulePayload)&&(identical(other.target, target) || other.target == target)&&(identical(other.disabled, disabled) || other.disabled == disabled)&&(identical(other.managed, managed) || other.managed == managed)&&(identical(other.ruleSet, ruleSet) || other.ruleSet == ruleSet)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.entry, entry) || other.entry == entry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,index,type,ruleType,payload,rulePayload,target,disabled,managed,ruleSet,status,reason,detail,entry);
}

@override
String toString() {
    return 'RuleHit(index: $index, type: $type, ruleType: $ruleType, payload: $payload, rulePayload: $rulePayload, target: $target, disabled: $disabled, managed: $managed, ruleSet: $ruleSet, status: $status, reason: $reason, detail: $detail, entry: $entry)';
}


}

/// @nodoc
abstract mixin class _$RuleHitCopyWith<$Res> implements $RuleHitCopyWith<$Res> {
  factory _$RuleHitCopyWith(_RuleHit value, $Res Function(_RuleHit) _then) = __$RuleHitCopyWithImpl;
@override @useResult
$Res call({
 int index, String type,@JsonKey(name: 'rule-type') String ruleType, String payload,@JsonKey(name: 'rule-payload') String rulePayload, String target, bool disabled, bool managed,@JsonKey(name: 'rule-set') RuleSetView? ruleSet,@JsonKey(unknownEnumValue: RuleHitStatus.uncertain) RuleHitStatus status, String reason, String detail, String entry
});


@override $RuleSetViewCopyWith<$Res>? get ruleSet;

}
/// @nodoc
class __$RuleHitCopyWithImpl<$Res>
    implements _$RuleHitCopyWith<$Res> {
  __$RuleHitCopyWithImpl(this._self, this._then);

  final _RuleHit _self;
  final $Res Function(_RuleHit) _then;

/// Create a copy of RuleHit
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? type = null,Object? ruleType = null,Object? payload = null,Object? rulePayload = null,Object? target = null,Object? disabled = null,Object? managed = null,Object? ruleSet = freezed,Object? status = null,Object? reason = null,Object? detail = null,Object? entry = null,}) {
  return _then(_RuleHit(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,ruleType: null == ruleType ? _self.ruleType : ruleType // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as String,rulePayload: null == rulePayload ? _self.rulePayload : rulePayload // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,disabled: null == disabled ? _self.disabled : disabled // ignore: cast_nullable_to_non_nullable
as bool,managed: null == managed ? _self.managed : managed // ignore: cast_nullable_to_non_nullable
as bool,ruleSet: freezed == ruleSet ? _self.ruleSet : ruleSet // ignore: cast_nullable_to_non_nullable
as RuleSetView?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RuleHitStatus,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of RuleHit
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RuleSetViewCopyWith<$Res>? get ruleSet {
    if (_self.ruleSet == null) {
    return null;
  }

  return $RuleSetViewCopyWith<$Res>(_self.ruleSet!, (value) {
    return _then(_self.copyWith(ruleSet: value));
  });
}
}


/// @nodoc
mixin _$RuleLookup {

@JsonKey(name: 'core-epoch') int get coreEpoch; String get mode; String get host; String get ip;@JsonKey(name: 'ip-source') String get ipSource;@JsonKey(name: 'resolve-error') String get resolveError;@JsonKey(name: 'resolve-wanted') bool get resolveWanted; int get port; String get network;@JsonKey(name: 'managed-prefix') int get managedPrefix; int get total; RuleHit? get winner; String get undetermined; List<ChainHop> get chain; List<RuleHit> get matches; List<RuleHit> get uncertain;@JsonKey(name: 'rule-sets') List<RuleSetView> get ruleSets;
/// Create a copy of RuleLookup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleLookupCopyWith<RuleLookup> get copyWith => _$RuleLookupCopyWithImpl<RuleLookup>(this as RuleLookup, _$identity);

  /// Serializes this RuleLookup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RuleLookup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleLookup&&(identical(other.coreEpoch, _this.coreEpoch) || other.coreEpoch == _this.coreEpoch)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.ip, _this.ip) || other.ip == _this.ip)&&(identical(other.ipSource, _this.ipSource) || other.ipSource == _this.ipSource)&&(identical(other.resolveError, _this.resolveError) || other.resolveError == _this.resolveError)&&(identical(other.resolveWanted, _this.resolveWanted) || other.resolveWanted == _this.resolveWanted)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.network, _this.network) || other.network == _this.network)&&(identical(other.managedPrefix, _this.managedPrefix) || other.managedPrefix == _this.managedPrefix)&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.winner, _this.winner) || other.winner == _this.winner)&&(identical(other.undetermined, _this.undetermined) || other.undetermined == _this.undetermined)&&const DeepCollectionEquality().equals(other.chain, _this.chain)&&const DeepCollectionEquality().equals(other.matches, _this.matches)&&const DeepCollectionEquality().equals(other.uncertain, _this.uncertain)&&const DeepCollectionEquality().equals(other.ruleSets, _this.ruleSets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RuleLookup;
  return Object.hash(runtimeType,_this.coreEpoch,_this.mode,_this.host,_this.ip,_this.ipSource,_this.resolveError,_this.resolveWanted,_this.port,_this.network,_this.managedPrefix,_this.total,_this.winner,_this.undetermined,const DeepCollectionEquality().hash(_this.chain),const DeepCollectionEquality().hash(_this.matches),const DeepCollectionEquality().hash(_this.uncertain),const DeepCollectionEquality().hash(_this.ruleSets));
}

@override
String toString() {
  final _this = this as RuleLookup;
  return 'RuleLookup(coreEpoch: ${_this.coreEpoch}, mode: ${_this.mode}, host: ${_this.host}, ip: ${_this.ip}, ipSource: ${_this.ipSource}, resolveError: ${_this.resolveError}, resolveWanted: ${_this.resolveWanted}, port: ${_this.port}, network: ${_this.network}, managedPrefix: ${_this.managedPrefix}, total: ${_this.total}, winner: ${_this.winner}, undetermined: ${_this.undetermined}, chain: ${_this.chain}, matches: ${_this.matches}, uncertain: ${_this.uncertain}, ruleSets: ${_this.ruleSets})';
}


}

/// @nodoc
abstract mixin class $RuleLookupCopyWith<$Res>  {
  factory $RuleLookupCopyWith(RuleLookup value, $Res Function(RuleLookup) _then) = _$RuleLookupCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'core-epoch') int coreEpoch, String mode, String host, String ip,@JsonKey(name: 'ip-source') String ipSource,@JsonKey(name: 'resolve-error') String resolveError,@JsonKey(name: 'resolve-wanted') bool resolveWanted, int port, String network,@JsonKey(name: 'managed-prefix') int managedPrefix, int total, RuleHit? winner, String undetermined, List<ChainHop> chain, List<RuleHit> matches, List<RuleHit> uncertain,@JsonKey(name: 'rule-sets') List<RuleSetView> ruleSets
});


$RuleHitCopyWith<$Res>? get winner;

}
/// @nodoc
class _$RuleLookupCopyWithImpl<$Res>
    implements $RuleLookupCopyWith<$Res> {
  _$RuleLookupCopyWithImpl(this._self, this._then);

  final RuleLookup _self;
  final $Res Function(RuleLookup) _then;

/// Create a copy of RuleLookup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? coreEpoch = null,Object? mode = null,Object? host = null,Object? ip = null,Object? ipSource = null,Object? resolveError = null,Object? resolveWanted = null,Object? port = null,Object? network = null,Object? managedPrefix = null,Object? total = null,Object? winner = freezed,Object? undetermined = null,Object? chain = null,Object? matches = null,Object? uncertain = null,Object? ruleSets = null,}) {
  return _then(RuleLookup(
coreEpoch: null == coreEpoch ? _self.coreEpoch : coreEpoch // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,ipSource: null == ipSource ? _self.ipSource : ipSource // ignore: cast_nullable_to_non_nullable
as String,resolveError: null == resolveError ? _self.resolveError : resolveError // ignore: cast_nullable_to_non_nullable
as String,resolveWanted: null == resolveWanted ? _self.resolveWanted : resolveWanted // ignore: cast_nullable_to_non_nullable
as bool,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as String,managedPrefix: null == managedPrefix ? _self.managedPrefix : managedPrefix // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,winner: freezed == winner ? _self.winner : winner // ignore: cast_nullable_to_non_nullable
as RuleHit?,undetermined: null == undetermined ? _self.undetermined : undetermined // ignore: cast_nullable_to_non_nullable
as String,chain: null == chain ? _self.chain : chain // ignore: cast_nullable_to_non_nullable
as List<ChainHop>,matches: null == matches ? _self.matches : matches // ignore: cast_nullable_to_non_nullable
as List<RuleHit>,uncertain: null == uncertain ? _self.uncertain : uncertain // ignore: cast_nullable_to_non_nullable
as List<RuleHit>,ruleSets: null == ruleSets ? _self.ruleSets : ruleSets // ignore: cast_nullable_to_non_nullable
as List<RuleSetView>,
  ));
}
/// Create a copy of RuleLookup
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RuleHitCopyWith<$Res>? get winner {
    if (_self.winner == null) {
    return null;
  }

  return $RuleHitCopyWith<$Res>(_self.winner!, (value) {
    return _then(_self.copyWith(winner: value));
  });
}
}


/// Adds pattern-matching-related methods to [RuleLookup].
extension RuleLookupPatterns on RuleLookup {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleLookup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleLookup() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleLookup value)  $default,){
final _that = this;
switch (_that) {
case _RuleLookup():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleLookup value)?  $default,){
final _that = this;
switch (_that) {
case _RuleLookup() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'core-epoch')  int coreEpoch,  String mode,  String host,  String ip, @JsonKey(name: 'ip-source')  String ipSource, @JsonKey(name: 'resolve-error')  String resolveError, @JsonKey(name: 'resolve-wanted')  bool resolveWanted,  int port,  String network, @JsonKey(name: 'managed-prefix')  int managedPrefix,  int total,  RuleHit? winner,  String undetermined,  List<ChainHop> chain,  List<RuleHit> matches,  List<RuleHit> uncertain, @JsonKey(name: 'rule-sets')  List<RuleSetView> ruleSets)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleLookup() when $default != null:
return $default(_that.coreEpoch,_that.mode,_that.host,_that.ip,_that.ipSource,_that.resolveError,_that.resolveWanted,_that.port,_that.network,_that.managedPrefix,_that.total,_that.winner,_that.undetermined,_that.chain,_that.matches,_that.uncertain,_that.ruleSets);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'core-epoch')  int coreEpoch,  String mode,  String host,  String ip, @JsonKey(name: 'ip-source')  String ipSource, @JsonKey(name: 'resolve-error')  String resolveError, @JsonKey(name: 'resolve-wanted')  bool resolveWanted,  int port,  String network, @JsonKey(name: 'managed-prefix')  int managedPrefix,  int total,  RuleHit? winner,  String undetermined,  List<ChainHop> chain,  List<RuleHit> matches,  List<RuleHit> uncertain, @JsonKey(name: 'rule-sets')  List<RuleSetView> ruleSets)  $default,) {final _that = this;
switch (_that) {
case _RuleLookup():
return $default(_that.coreEpoch,_that.mode,_that.host,_that.ip,_that.ipSource,_that.resolveError,_that.resolveWanted,_that.port,_that.network,_that.managedPrefix,_that.total,_that.winner,_that.undetermined,_that.chain,_that.matches,_that.uncertain,_that.ruleSets);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'core-epoch')  int coreEpoch,  String mode,  String host,  String ip, @JsonKey(name: 'ip-source')  String ipSource, @JsonKey(name: 'resolve-error')  String resolveError, @JsonKey(name: 'resolve-wanted')  bool resolveWanted,  int port,  String network, @JsonKey(name: 'managed-prefix')  int managedPrefix,  int total,  RuleHit? winner,  String undetermined,  List<ChainHop> chain,  List<RuleHit> matches,  List<RuleHit> uncertain, @JsonKey(name: 'rule-sets')  List<RuleSetView> ruleSets)?  $default,) {final _that = this;
switch (_that) {
case _RuleLookup() when $default != null:
return $default(_that.coreEpoch,_that.mode,_that.host,_that.ip,_that.ipSource,_that.resolveError,_that.resolveWanted,_that.port,_that.network,_that.managedPrefix,_that.total,_that.winner,_that.undetermined,_that.chain,_that.matches,_that.uncertain,_that.ruleSets);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuleLookup implements RuleLookup {
  const _RuleLookup({@JsonKey(name: 'core-epoch') this.coreEpoch = 0, this.mode = '', this.host = '', this.ip = '', @JsonKey(name: 'ip-source') this.ipSource = '', @JsonKey(name: 'resolve-error') this.resolveError = '', @JsonKey(name: 'resolve-wanted') this.resolveWanted = false, this.port = 0, this.network = '', @JsonKey(name: 'managed-prefix') this.managedPrefix = 0, this.total = 0, this.winner, this.undetermined = '',  List<ChainHop> chain = const [],  List<RuleHit> matches = const [],  List<RuleHit> uncertain = const [], @JsonKey(name: 'rule-sets')  List<RuleSetView> ruleSets = const []}): _chain = chain,_matches = matches,_uncertain = uncertain,_ruleSets = ruleSets;
  factory _RuleLookup.fromJson(Map<String, dynamic> json) => _$RuleLookupFromJson(json);

@override@JsonKey(name: 'core-epoch') final  int coreEpoch;
@override@JsonKey() final  String mode;
@override@JsonKey() final  String host;
@override@JsonKey() final  String ip;
@override@JsonKey(name: 'ip-source') final  String ipSource;
@override@JsonKey(name: 'resolve-error') final  String resolveError;
@override@JsonKey(name: 'resolve-wanted') final  bool resolveWanted;
@override@JsonKey() final  int port;
@override@JsonKey() final  String network;
@override@JsonKey(name: 'managed-prefix') final  int managedPrefix;
@override@JsonKey() final  int total;
@override final  RuleHit? winner;
@override@JsonKey() final  String undetermined;
 final  List<ChainHop> _chain;
@override@JsonKey() List<ChainHop> get chain {
  if (_chain is EqualUnmodifiableListView) return _chain;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chain);
}

 final  List<RuleHit> _matches;
@override@JsonKey() List<RuleHit> get matches {
  if (_matches is EqualUnmodifiableListView) return _matches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_matches);
}

 final  List<RuleHit> _uncertain;
@override@JsonKey() List<RuleHit> get uncertain {
  if (_uncertain is EqualUnmodifiableListView) return _uncertain;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_uncertain);
}

 final  List<RuleSetView> _ruleSets;
@override@JsonKey(name: 'rule-sets') List<RuleSetView> get ruleSets {
  if (_ruleSets is EqualUnmodifiableListView) return _ruleSets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ruleSets);
}


/// Create a copy of RuleLookup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleLookupCopyWith<_RuleLookup> get copyWith => __$RuleLookupCopyWithImpl<_RuleLookup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuleLookupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleLookup&&(identical(other.coreEpoch, coreEpoch) || other.coreEpoch == coreEpoch)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.host, host) || other.host == host)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.ipSource, ipSource) || other.ipSource == ipSource)&&(identical(other.resolveError, resolveError) || other.resolveError == resolveError)&&(identical(other.resolveWanted, resolveWanted) || other.resolveWanted == resolveWanted)&&(identical(other.port, port) || other.port == port)&&(identical(other.network, network) || other.network == network)&&(identical(other.managedPrefix, managedPrefix) || other.managedPrefix == managedPrefix)&&(identical(other.total, total) || other.total == total)&&(identical(other.winner, winner) || other.winner == winner)&&(identical(other.undetermined, undetermined) || other.undetermined == undetermined)&&const DeepCollectionEquality().equals(other.chain, _chain)&&const DeepCollectionEquality().equals(other.matches, _matches)&&const DeepCollectionEquality().equals(other.uncertain, _uncertain)&&const DeepCollectionEquality().equals(other.ruleSets, _ruleSets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,coreEpoch,mode,host,ip,ipSource,resolveError,resolveWanted,port,network,managedPrefix,total,winner,undetermined,const DeepCollectionEquality().hash(_chain),const DeepCollectionEquality().hash(_matches),const DeepCollectionEquality().hash(_uncertain),const DeepCollectionEquality().hash(_ruleSets));
}

@override
String toString() {
    return 'RuleLookup(coreEpoch: $coreEpoch, mode: $mode, host: $host, ip: $ip, ipSource: $ipSource, resolveError: $resolveError, resolveWanted: $resolveWanted, port: $port, network: $network, managedPrefix: $managedPrefix, total: $total, winner: $winner, undetermined: $undetermined, chain: $chain, matches: $matches, uncertain: $uncertain, ruleSets: $ruleSets)';
}


}

/// @nodoc
abstract mixin class _$RuleLookupCopyWith<$Res> implements $RuleLookupCopyWith<$Res> {
  factory _$RuleLookupCopyWith(_RuleLookup value, $Res Function(_RuleLookup) _then) = __$RuleLookupCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'core-epoch') int coreEpoch, String mode, String host, String ip,@JsonKey(name: 'ip-source') String ipSource,@JsonKey(name: 'resolve-error') String resolveError,@JsonKey(name: 'resolve-wanted') bool resolveWanted, int port, String network,@JsonKey(name: 'managed-prefix') int managedPrefix, int total, RuleHit? winner, String undetermined, List<ChainHop> chain, List<RuleHit> matches, List<RuleHit> uncertain,@JsonKey(name: 'rule-sets') List<RuleSetView> ruleSets
});


@override $RuleHitCopyWith<$Res>? get winner;

}
/// @nodoc
class __$RuleLookupCopyWithImpl<$Res>
    implements _$RuleLookupCopyWith<$Res> {
  __$RuleLookupCopyWithImpl(this._self, this._then);

  final _RuleLookup _self;
  final $Res Function(_RuleLookup) _then;

/// Create a copy of RuleLookup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? coreEpoch = null,Object? mode = null,Object? host = null,Object? ip = null,Object? ipSource = null,Object? resolveError = null,Object? resolveWanted = null,Object? port = null,Object? network = null,Object? managedPrefix = null,Object? total = null,Object? winner = freezed,Object? undetermined = null,Object? chain = null,Object? matches = null,Object? uncertain = null,Object? ruleSets = null,}) {
  return _then(_RuleLookup(
coreEpoch: null == coreEpoch ? _self.coreEpoch : coreEpoch // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,ipSource: null == ipSource ? _self.ipSource : ipSource // ignore: cast_nullable_to_non_nullable
as String,resolveError: null == resolveError ? _self.resolveError : resolveError // ignore: cast_nullable_to_non_nullable
as String,resolveWanted: null == resolveWanted ? _self.resolveWanted : resolveWanted // ignore: cast_nullable_to_non_nullable
as bool,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,network: null == network ? _self.network : network // ignore: cast_nullable_to_non_nullable
as String,managedPrefix: null == managedPrefix ? _self.managedPrefix : managedPrefix // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,winner: freezed == winner ? _self.winner : winner // ignore: cast_nullable_to_non_nullable
as RuleHit?,undetermined: null == undetermined ? _self.undetermined : undetermined // ignore: cast_nullable_to_non_nullable
as String,chain: null == chain ? _self._chain : chain // ignore: cast_nullable_to_non_nullable
as List<ChainHop>,matches: null == matches ? _self._matches : matches // ignore: cast_nullable_to_non_nullable
as List<RuleHit>,uncertain: null == uncertain ? _self._uncertain : uncertain // ignore: cast_nullable_to_non_nullable
as List<RuleHit>,ruleSets: null == ruleSets ? _self._ruleSets : ruleSets // ignore: cast_nullable_to_non_nullable
as List<RuleSetView>,
  ));
}

/// Create a copy of RuleLookup
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RuleHitCopyWith<$Res>? get winner {
    if (_self.winner == null) {
    return null;
  }

  return $RuleHitCopyWith<$Res>(_self.winner!, (value) {
    return _then(_self.copyWith(winner: value));
  });
}
}

/// @nodoc
mixin _$RuleSource {

 RuleSourceKind get kind; String get name; String get text;
/// Create a copy of RuleSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleSourceCopyWith<RuleSource> get copyWith => _$RuleSourceCopyWithImpl<RuleSource>(this as RuleSource, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RuleSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleSource&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.text, _this.text) || other.text == _this.text));
}


@override
int get hashCode {
  final _this = this as RuleSource;
  return Object.hash(runtimeType,_this.kind,_this.name,_this.text);
}

@override
String toString() {
  final _this = this as RuleSource;
  return 'RuleSource(kind: ${_this.kind}, name: ${_this.name}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $RuleSourceCopyWith<$Res>  {
  factory $RuleSourceCopyWith(RuleSource value, $Res Function(RuleSource) _then) = _$RuleSourceCopyWithImpl;
@useResult
$Res call({
 RuleSourceKind kind, String name, String text
});




}
/// @nodoc
class _$RuleSourceCopyWithImpl<$Res>
    implements $RuleSourceCopyWith<$Res> {
  _$RuleSourceCopyWithImpl(this._self, this._then);

  final RuleSource _self;
  final $Res Function(RuleSource) _then;

/// Create a copy of RuleSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? name = null,Object? text = null,}) {
  return _then(RuleSource(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RuleSourceKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RuleSource].
extension RuleSourcePatterns on RuleSource {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleSource() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleSource value)  $default,){
final _that = this;
switch (_that) {
case _RuleSource():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleSource value)?  $default,){
final _that = this;
switch (_that) {
case _RuleSource() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RuleSourceKind kind,  String name,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleSource() when $default != null:
return $default(_that.kind,_that.name,_that.text);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RuleSourceKind kind,  String name,  String text)  $default,) {final _that = this;
switch (_that) {
case _RuleSource():
return $default(_that.kind,_that.name,_that.text);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RuleSourceKind kind,  String name,  String text)?  $default,) {final _that = this;
switch (_that) {
case _RuleSource() when $default != null:
return $default(_that.kind,_that.name,_that.text);case _:
  return null;

}
}

}

/// @nodoc


class _RuleSource implements RuleSource {
  const _RuleSource({required this.kind, this.name = '', this.text = ''});
  

@override final  RuleSourceKind kind;
@override@JsonKey() final  String name;
@override@JsonKey() final  String text;

/// Create a copy of RuleSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleSourceCopyWith<_RuleSource> get copyWith => __$RuleSourceCopyWithImpl<_RuleSource>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleSource&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,name,text);
}

@override
String toString() {
    return 'RuleSource(kind: $kind, name: $name, text: $text)';
}


}

/// @nodoc
abstract mixin class _$RuleSourceCopyWith<$Res> implements $RuleSourceCopyWith<$Res> {
  factory _$RuleSourceCopyWith(_RuleSource value, $Res Function(_RuleSource) _then) = __$RuleSourceCopyWithImpl;
@override @useResult
$Res call({
 RuleSourceKind kind, String name, String text
});




}
/// @nodoc
class __$RuleSourceCopyWithImpl<$Res>
    implements _$RuleSourceCopyWith<$Res> {
  __$RuleSourceCopyWithImpl(this._self, this._then);

  final _RuleSource _self;
  final $Res Function(_RuleSource) _then;

/// Create a copy of RuleSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? name = null,Object? text = null,}) {
  return _then(_RuleSource(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as RuleSourceKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$AppliedRuleSources {

 int? get profileId; List<RuleSource> get sources; int? get epoch;
/// Create a copy of AppliedRuleSources
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppliedRuleSourcesCopyWith<AppliedRuleSources> get copyWith => _$AppliedRuleSourcesCopyWithImpl<AppliedRuleSources>(this as AppliedRuleSources, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AppliedRuleSources;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppliedRuleSources&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&const DeepCollectionEquality().equals(other.sources, _this.sources)&&(identical(other.epoch, _this.epoch) || other.epoch == _this.epoch));
}


@override
int get hashCode {
  final _this = this as AppliedRuleSources;
  return Object.hash(runtimeType,_this.profileId,const DeepCollectionEquality().hash(_this.sources),_this.epoch);
}

@override
String toString() {
  final _this = this as AppliedRuleSources;
  return 'AppliedRuleSources(profileId: ${_this.profileId}, sources: ${_this.sources}, epoch: ${_this.epoch})';
}


}

/// @nodoc
abstract mixin class $AppliedRuleSourcesCopyWith<$Res>  {
  factory $AppliedRuleSourcesCopyWith(AppliedRuleSources value, $Res Function(AppliedRuleSources) _then) = _$AppliedRuleSourcesCopyWithImpl;
@useResult
$Res call({
 int? profileId, List<RuleSource> sources, int? epoch
});




}
/// @nodoc
class _$AppliedRuleSourcesCopyWithImpl<$Res>
    implements $AppliedRuleSourcesCopyWith<$Res> {
  _$AppliedRuleSourcesCopyWithImpl(this._self, this._then);

  final AppliedRuleSources _self;
  final $Res Function(AppliedRuleSources) _then;

/// Create a copy of AppliedRuleSources
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = freezed,Object? sources = null,Object? epoch = freezed,}) {
  return _then(AppliedRuleSources(
profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<RuleSource>,epoch: freezed == epoch ? _self.epoch : epoch // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppliedRuleSources].
extension AppliedRuleSourcesPatterns on AppliedRuleSources {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppliedRuleSources value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppliedRuleSources() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppliedRuleSources value)  $default,){
final _that = this;
switch (_that) {
case _AppliedRuleSources():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppliedRuleSources value)?  $default,){
final _that = this;
switch (_that) {
case _AppliedRuleSources() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? profileId,  List<RuleSource> sources,  int? epoch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppliedRuleSources() when $default != null:
return $default(_that.profileId,_that.sources,_that.epoch);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? profileId,  List<RuleSource> sources,  int? epoch)  $default,) {final _that = this;
switch (_that) {
case _AppliedRuleSources():
return $default(_that.profileId,_that.sources,_that.epoch);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? profileId,  List<RuleSource> sources,  int? epoch)?  $default,) {final _that = this;
switch (_that) {
case _AppliedRuleSources() when $default != null:
return $default(_that.profileId,_that.sources,_that.epoch);case _:
  return null;

}
}

}

/// @nodoc


class _AppliedRuleSources implements AppliedRuleSources {
  const _AppliedRuleSources({this.profileId,  List<RuleSource> sources = const [], this.epoch}): _sources = sources;
  

@override final  int? profileId;
 final  List<RuleSource> _sources;
@override@JsonKey() List<RuleSource> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}

@override final  int? epoch;

/// Create a copy of AppliedRuleSources
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppliedRuleSourcesCopyWith<_AppliedRuleSources> get copyWith => __$AppliedRuleSourcesCopyWithImpl<_AppliedRuleSources>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppliedRuleSources&&(identical(other.profileId, profileId) || other.profileId == profileId)&&const DeepCollectionEquality().equals(other.sources, _sources)&&(identical(other.epoch, epoch) || other.epoch == epoch));
}


@override
int get hashCode {
    return Object.hash(runtimeType,profileId,const DeepCollectionEquality().hash(_sources),epoch);
}

@override
String toString() {
    return 'AppliedRuleSources(profileId: $profileId, sources: $sources, epoch: $epoch)';
}


}

/// @nodoc
abstract mixin class _$AppliedRuleSourcesCopyWith<$Res> implements $AppliedRuleSourcesCopyWith<$Res> {
  factory _$AppliedRuleSourcesCopyWith(_AppliedRuleSources value, $Res Function(_AppliedRuleSources) _then) = __$AppliedRuleSourcesCopyWithImpl;
@override @useResult
$Res call({
 int? profileId, List<RuleSource> sources, int? epoch
});




}
/// @nodoc
class __$AppliedRuleSourcesCopyWithImpl<$Res>
    implements _$AppliedRuleSourcesCopyWith<$Res> {
  __$AppliedRuleSourcesCopyWithImpl(this._self, this._then);

  final _AppliedRuleSources _self;
  final $Res Function(_AppliedRuleSources) _then;

/// Create a copy of AppliedRuleSources
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = freezed,Object? sources = null,Object? epoch = freezed,}) {
  return _then(_AppliedRuleSources(
profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<RuleSource>,epoch: freezed == epoch ? _self.epoch : epoch // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
