// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../tailscale.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TailscaleError {

 String get code; String get message;
/// Create a copy of TailscaleError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<TailscaleError> get copyWith => _$TailscaleErrorCopyWithImpl<TailscaleError>(this as TailscaleError, _$identity);

  /// Serializes this TailscaleError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleError;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleError&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleError;
  return Object.hash(runtimeType,_this.code,_this.message);
}

@override
String toString() {
  final _this = this as TailscaleError;
  return 'TailscaleError(code: ${_this.code}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $TailscaleErrorCopyWith<$Res>  {
  factory $TailscaleErrorCopyWith(TailscaleError value, $Res Function(TailscaleError) _then) = _$TailscaleErrorCopyWithImpl;
@useResult
$Res call({
 String code, String message
});




}
/// @nodoc
class _$TailscaleErrorCopyWithImpl<$Res>
    implements $TailscaleErrorCopyWith<$Res> {
  _$TailscaleErrorCopyWithImpl(this._self, this._then);

  final TailscaleError _self;
  final $Res Function(TailscaleError) _then;

/// Create a copy of TailscaleError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? message = null,}) {
  return _then(TailscaleError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleError].
extension TailscaleErrorPatterns on TailscaleError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleError value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleError value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleError() when $default != null:
return $default(_that.code,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String message)  $default,) {final _that = this;
switch (_that) {
case _TailscaleError():
return $default(_that.code,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String message)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleError() when $default != null:
return $default(_that.code,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleError implements TailscaleError {
  const _TailscaleError({this.code = '', this.message = ''});
  factory _TailscaleError.fromJson(Map<String, dynamic> json) => _$TailscaleErrorFromJson(json);

@override@JsonKey() final  String code;
@override@JsonKey() final  String message;

/// Create a copy of TailscaleError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleErrorCopyWith<_TailscaleError> get copyWith => __$TailscaleErrorCopyWithImpl<_TailscaleError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleErrorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleError&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,message);
}

@override
String toString() {
    return 'TailscaleError(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class _$TailscaleErrorCopyWith<$Res> implements $TailscaleErrorCopyWith<$Res> {
  factory _$TailscaleErrorCopyWith(_TailscaleError value, $Res Function(_TailscaleError) _then) = __$TailscaleErrorCopyWithImpl;
@override @useResult
$Res call({
 String code, String message
});




}
/// @nodoc
class __$TailscaleErrorCopyWithImpl<$Res>
    implements _$TailscaleErrorCopyWith<$Res> {
  __$TailscaleErrorCopyWithImpl(this._self, this._then);

  final _TailscaleError _self;
  final $Res Function(_TailscaleError) _then;

/// Create a copy of TailscaleError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = null,}) {
  return _then(_TailscaleError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TailscaleExitNodeSetting {

 String get value;@JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) TailscaleSettingSource get source;
/// Create a copy of TailscaleExitNodeSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleExitNodeSettingCopyWith<TailscaleExitNodeSetting> get copyWith => _$TailscaleExitNodeSettingCopyWithImpl<TailscaleExitNodeSetting>(this as TailscaleExitNodeSetting, _$identity);

  /// Serializes this TailscaleExitNodeSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleExitNodeSetting;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleExitNodeSetting&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.source, _this.source) || other.source == _this.source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleExitNodeSetting;
  return Object.hash(runtimeType,_this.value,_this.source);
}

@override
String toString() {
  final _this = this as TailscaleExitNodeSetting;
  return 'TailscaleExitNodeSetting(value: ${_this.value}, source: ${_this.source})';
}


}

/// @nodoc
abstract mixin class $TailscaleExitNodeSettingCopyWith<$Res>  {
  factory $TailscaleExitNodeSettingCopyWith(TailscaleExitNodeSetting value, $Res Function(TailscaleExitNodeSetting) _then) = _$TailscaleExitNodeSettingCopyWithImpl;
@useResult
$Res call({
 String value,@JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) TailscaleSettingSource source
});




}
/// @nodoc
class _$TailscaleExitNodeSettingCopyWithImpl<$Res>
    implements $TailscaleExitNodeSettingCopyWith<$Res> {
  _$TailscaleExitNodeSettingCopyWithImpl(this._self, this._then);

  final TailscaleExitNodeSetting _self;
  final $Res Function(TailscaleExitNodeSetting) _then;

/// Create a copy of TailscaleExitNodeSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? source = null,}) {
  return _then(TailscaleExitNodeSetting(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TailscaleSettingSource,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleExitNodeSetting].
extension TailscaleExitNodeSettingPatterns on TailscaleExitNodeSetting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleExitNodeSetting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleExitNodeSetting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleExitNodeSetting value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleExitNodeSetting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleExitNodeSetting value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleExitNodeSetting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value, @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault)  TailscaleSettingSource source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleExitNodeSetting() when $default != null:
return $default(_that.value,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value, @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault)  TailscaleSettingSource source)  $default,) {final _that = this;
switch (_that) {
case _TailscaleExitNodeSetting():
return $default(_that.value,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value, @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault)  TailscaleSettingSource source)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleExitNodeSetting() when $default != null:
return $default(_that.value,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleExitNodeSetting implements TailscaleExitNodeSetting {
  const _TailscaleExitNodeSetting({this.value = '', @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) this.source = TailscaleSettingSource.coreDefault});
  factory _TailscaleExitNodeSetting.fromJson(Map<String, dynamic> json) => _$TailscaleExitNodeSettingFromJson(json);

@override@JsonKey() final  String value;
@override@JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) final  TailscaleSettingSource source;

/// Create a copy of TailscaleExitNodeSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleExitNodeSettingCopyWith<_TailscaleExitNodeSetting> get copyWith => __$TailscaleExitNodeSettingCopyWithImpl<_TailscaleExitNodeSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleExitNodeSettingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleExitNodeSetting&&(identical(other.value, value) || other.value == value)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value,source);
}

@override
String toString() {
    return 'TailscaleExitNodeSetting(value: $value, source: $source)';
}


}

/// @nodoc
abstract mixin class _$TailscaleExitNodeSettingCopyWith<$Res> implements $TailscaleExitNodeSettingCopyWith<$Res> {
  factory _$TailscaleExitNodeSettingCopyWith(_TailscaleExitNodeSetting value, $Res Function(_TailscaleExitNodeSetting) _then) = __$TailscaleExitNodeSettingCopyWithImpl;
@override @useResult
$Res call({
 String value,@JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) TailscaleSettingSource source
});




}
/// @nodoc
class __$TailscaleExitNodeSettingCopyWithImpl<$Res>
    implements _$TailscaleExitNodeSettingCopyWith<$Res> {
  __$TailscaleExitNodeSettingCopyWithImpl(this._self, this._then);

  final _TailscaleExitNodeSetting _self;
  final $Res Function(_TailscaleExitNodeSetting) _then;

/// Create a copy of TailscaleExitNodeSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? source = null,}) {
  return _then(_TailscaleExitNodeSetting(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TailscaleSettingSource,
  ));
}


}


/// @nodoc
mixin _$TailscaleAcceptRoutesSetting {

 bool get value;@JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) TailscaleSettingSource get source;
/// Create a copy of TailscaleAcceptRoutesSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleAcceptRoutesSettingCopyWith<TailscaleAcceptRoutesSetting> get copyWith => _$TailscaleAcceptRoutesSettingCopyWithImpl<TailscaleAcceptRoutesSetting>(this as TailscaleAcceptRoutesSetting, _$identity);

  /// Serializes this TailscaleAcceptRoutesSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleAcceptRoutesSetting;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleAcceptRoutesSetting&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.source, _this.source) || other.source == _this.source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleAcceptRoutesSetting;
  return Object.hash(runtimeType,_this.value,_this.source);
}

@override
String toString() {
  final _this = this as TailscaleAcceptRoutesSetting;
  return 'TailscaleAcceptRoutesSetting(value: ${_this.value}, source: ${_this.source})';
}


}

/// @nodoc
abstract mixin class $TailscaleAcceptRoutesSettingCopyWith<$Res>  {
  factory $TailscaleAcceptRoutesSettingCopyWith(TailscaleAcceptRoutesSetting value, $Res Function(TailscaleAcceptRoutesSetting) _then) = _$TailscaleAcceptRoutesSettingCopyWithImpl;
@useResult
$Res call({
 bool value,@JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) TailscaleSettingSource source
});




}
/// @nodoc
class _$TailscaleAcceptRoutesSettingCopyWithImpl<$Res>
    implements $TailscaleAcceptRoutesSettingCopyWith<$Res> {
  _$TailscaleAcceptRoutesSettingCopyWithImpl(this._self, this._then);

  final TailscaleAcceptRoutesSetting _self;
  final $Res Function(TailscaleAcceptRoutesSetting) _then;

/// Create a copy of TailscaleAcceptRoutesSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? source = null,}) {
  return _then(TailscaleAcceptRoutesSetting(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as bool,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TailscaleSettingSource,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleAcceptRoutesSetting].
extension TailscaleAcceptRoutesSettingPatterns on TailscaleAcceptRoutesSetting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleAcceptRoutesSetting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleAcceptRoutesSetting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleAcceptRoutesSetting value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleAcceptRoutesSetting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleAcceptRoutesSetting value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleAcceptRoutesSetting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool value, @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault)  TailscaleSettingSource source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleAcceptRoutesSetting() when $default != null:
return $default(_that.value,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool value, @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault)  TailscaleSettingSource source)  $default,) {final _that = this;
switch (_that) {
case _TailscaleAcceptRoutesSetting():
return $default(_that.value,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool value, @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault)  TailscaleSettingSource source)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleAcceptRoutesSetting() when $default != null:
return $default(_that.value,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleAcceptRoutesSetting implements TailscaleAcceptRoutesSetting {
  const _TailscaleAcceptRoutesSetting({this.value = false, @JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) this.source = TailscaleSettingSource.coreDefault});
  factory _TailscaleAcceptRoutesSetting.fromJson(Map<String, dynamic> json) => _$TailscaleAcceptRoutesSettingFromJson(json);

@override@JsonKey() final  bool value;
@override@JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) final  TailscaleSettingSource source;

/// Create a copy of TailscaleAcceptRoutesSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleAcceptRoutesSettingCopyWith<_TailscaleAcceptRoutesSetting> get copyWith => __$TailscaleAcceptRoutesSettingCopyWithImpl<_TailscaleAcceptRoutesSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleAcceptRoutesSettingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleAcceptRoutesSetting&&(identical(other.value, value) || other.value == value)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value,source);
}

@override
String toString() {
    return 'TailscaleAcceptRoutesSetting(value: $value, source: $source)';
}


}

/// @nodoc
abstract mixin class _$TailscaleAcceptRoutesSettingCopyWith<$Res> implements $TailscaleAcceptRoutesSettingCopyWith<$Res> {
  factory _$TailscaleAcceptRoutesSettingCopyWith(_TailscaleAcceptRoutesSetting value, $Res Function(_TailscaleAcceptRoutesSetting) _then) = __$TailscaleAcceptRoutesSettingCopyWithImpl;
@override @useResult
$Res call({
 bool value,@JsonKey(unknownEnumValue: TailscaleSettingSource.coreDefault) TailscaleSettingSource source
});




}
/// @nodoc
class __$TailscaleAcceptRoutesSettingCopyWithImpl<$Res>
    implements _$TailscaleAcceptRoutesSettingCopyWith<$Res> {
  __$TailscaleAcceptRoutesSettingCopyWithImpl(this._self, this._then);

  final _TailscaleAcceptRoutesSetting _self;
  final $Res Function(_TailscaleAcceptRoutesSetting) _then;

/// Create a copy of TailscaleAcceptRoutesSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? source = null,}) {
  return _then(_TailscaleAcceptRoutesSetting(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as bool,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TailscaleSettingSource,
  ));
}


}


/// @nodoc
mixin _$TailscaleSettings {

@JsonKey(name: 'exit-node') TailscaleExitNodeSetting get exitNode;@JsonKey(name: 'accept-routes') TailscaleAcceptRoutesSetting get acceptRoutes;
/// Create a copy of TailscaleSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleSettingsCopyWith<TailscaleSettings> get copyWith => _$TailscaleSettingsCopyWithImpl<TailscaleSettings>(this as TailscaleSettings, _$identity);

  /// Serializes this TailscaleSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleSettings&&(identical(other.exitNode, _this.exitNode) || other.exitNode == _this.exitNode)&&(identical(other.acceptRoutes, _this.acceptRoutes) || other.acceptRoutes == _this.acceptRoutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleSettings;
  return Object.hash(runtimeType,_this.exitNode,_this.acceptRoutes);
}

@override
String toString() {
  final _this = this as TailscaleSettings;
  return 'TailscaleSettings(exitNode: ${_this.exitNode}, acceptRoutes: ${_this.acceptRoutes})';
}


}

/// @nodoc
abstract mixin class $TailscaleSettingsCopyWith<$Res>  {
  factory $TailscaleSettingsCopyWith(TailscaleSettings value, $Res Function(TailscaleSettings) _then) = _$TailscaleSettingsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'exit-node') TailscaleExitNodeSetting exitNode,@JsonKey(name: 'accept-routes') TailscaleAcceptRoutesSetting acceptRoutes
});


$TailscaleExitNodeSettingCopyWith<$Res> get exitNode;$TailscaleAcceptRoutesSettingCopyWith<$Res> get acceptRoutes;

}
/// @nodoc
class _$TailscaleSettingsCopyWithImpl<$Res>
    implements $TailscaleSettingsCopyWith<$Res> {
  _$TailscaleSettingsCopyWithImpl(this._self, this._then);

  final TailscaleSettings _self;
  final $Res Function(TailscaleSettings) _then;

/// Create a copy of TailscaleSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? exitNode = null,Object? acceptRoutes = null,}) {
  return _then(TailscaleSettings(
exitNode: null == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as TailscaleExitNodeSetting,acceptRoutes: null == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as TailscaleAcceptRoutesSetting,
  ));
}
/// Create a copy of TailscaleSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleExitNodeSettingCopyWith<$Res> get exitNode {
  
  return $TailscaleExitNodeSettingCopyWith<$Res>(_self.exitNode, (value) {
    return _then(_self.copyWith(exitNode: value));
  });
}/// Create a copy of TailscaleSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleAcceptRoutesSettingCopyWith<$Res> get acceptRoutes {
  
  return $TailscaleAcceptRoutesSettingCopyWith<$Res>(_self.acceptRoutes, (value) {
    return _then(_self.copyWith(acceptRoutes: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleSettings].
extension TailscaleSettingsPatterns on TailscaleSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleSettings value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleSettings value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'exit-node')  TailscaleExitNodeSetting exitNode, @JsonKey(name: 'accept-routes')  TailscaleAcceptRoutesSetting acceptRoutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleSettings() when $default != null:
return $default(_that.exitNode,_that.acceptRoutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'exit-node')  TailscaleExitNodeSetting exitNode, @JsonKey(name: 'accept-routes')  TailscaleAcceptRoutesSetting acceptRoutes)  $default,) {final _that = this;
switch (_that) {
case _TailscaleSettings():
return $default(_that.exitNode,_that.acceptRoutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'exit-node')  TailscaleExitNodeSetting exitNode, @JsonKey(name: 'accept-routes')  TailscaleAcceptRoutesSetting acceptRoutes)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleSettings() when $default != null:
return $default(_that.exitNode,_that.acceptRoutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleSettings implements TailscaleSettings {
  const _TailscaleSettings({@JsonKey(name: 'exit-node') this.exitNode = const TailscaleExitNodeSetting(), @JsonKey(name: 'accept-routes') this.acceptRoutes = const TailscaleAcceptRoutesSetting()});
  factory _TailscaleSettings.fromJson(Map<String, dynamic> json) => _$TailscaleSettingsFromJson(json);

@override@JsonKey(name: 'exit-node') final  TailscaleExitNodeSetting exitNode;
@override@JsonKey(name: 'accept-routes') final  TailscaleAcceptRoutesSetting acceptRoutes;

/// Create a copy of TailscaleSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleSettingsCopyWith<_TailscaleSettings> get copyWith => __$TailscaleSettingsCopyWithImpl<_TailscaleSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleSettings&&(identical(other.exitNode, exitNode) || other.exitNode == exitNode)&&(identical(other.acceptRoutes, acceptRoutes) || other.acceptRoutes == acceptRoutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,exitNode,acceptRoutes);
}

@override
String toString() {
    return 'TailscaleSettings(exitNode: $exitNode, acceptRoutes: $acceptRoutes)';
}


}

/// @nodoc
abstract mixin class _$TailscaleSettingsCopyWith<$Res> implements $TailscaleSettingsCopyWith<$Res> {
  factory _$TailscaleSettingsCopyWith(_TailscaleSettings value, $Res Function(_TailscaleSettings) _then) = __$TailscaleSettingsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'exit-node') TailscaleExitNodeSetting exitNode,@JsonKey(name: 'accept-routes') TailscaleAcceptRoutesSetting acceptRoutes
});


@override $TailscaleExitNodeSettingCopyWith<$Res> get exitNode;@override $TailscaleAcceptRoutesSettingCopyWith<$Res> get acceptRoutes;

}
/// @nodoc
class __$TailscaleSettingsCopyWithImpl<$Res>
    implements _$TailscaleSettingsCopyWith<$Res> {
  __$TailscaleSettingsCopyWithImpl(this._self, this._then);

  final _TailscaleSettings _self;
  final $Res Function(_TailscaleSettings) _then;

/// Create a copy of TailscaleSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? exitNode = null,Object? acceptRoutes = null,}) {
  return _then(_TailscaleSettings(
exitNode: null == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as TailscaleExitNodeSetting,acceptRoutes: null == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as TailscaleAcceptRoutesSetting,
  ));
}

/// Create a copy of TailscaleSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleExitNodeSettingCopyWith<$Res> get exitNode {
  
  return $TailscaleExitNodeSettingCopyWith<$Res>(_self.exitNode, (value) {
    return _then(_self.copyWith(exitNode: value));
  });
}/// Create a copy of TailscaleSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleAcceptRoutesSettingCopyWith<$Res> get acceptRoutes {
  
  return $TailscaleAcceptRoutesSettingCopyWith<$Res>(_self.acceptRoutes, (value) {
    return _then(_self.copyWith(acceptRoutes: value));
  });
}
}


/// @nodoc
mixin _$TailscaleNode {

@JsonKey(name: 'profile-id') int get profileId; String get name;@JsonKey(name: 'managed-id') String get managedId; bool get attached; TailscaleAccount? get account; int get generation;@JsonKey(name: 'control-url') String get controlUrl; String get hostname;@JsonKey(name: 'state-dir-mode', unknownEnumValue: TailscaleStateDirMode.shared) TailscaleStateDirMode get stateDirMode; bool get started;@JsonKey(name: 'backend-state', unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState get backendState;@JsonKey(name: 'logged-out') bool get loggedOut;@JsonKey(name: 'has-identity') bool get hasIdentity;@JsonKey(name: 'auth-key') bool get authKey; bool get ephemeral; bool get overridable;@JsonKey(name: 'start-error') TailscaleError? get startError; TailscaleSettings get settings; List<String> get warnings; TailscaleLegacyIdentity? get legacy;
/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleNodeCopyWith<TailscaleNode> get copyWith => _$TailscaleNodeCopyWithImpl<TailscaleNode>(this as TailscaleNode, _$identity);

  /// Serializes this TailscaleNode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleNode;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleNode&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.managedId, _this.managedId) || other.managedId == _this.managedId)&&(identical(other.attached, _this.attached) || other.attached == _this.attached)&&(identical(other.account, _this.account) || other.account == _this.account)&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl)&&(identical(other.hostname, _this.hostname) || other.hostname == _this.hostname)&&(identical(other.stateDirMode, _this.stateDirMode) || other.stateDirMode == _this.stateDirMode)&&(identical(other.started, _this.started) || other.started == _this.started)&&(identical(other.backendState, _this.backendState) || other.backendState == _this.backendState)&&(identical(other.loggedOut, _this.loggedOut) || other.loggedOut == _this.loggedOut)&&(identical(other.hasIdentity, _this.hasIdentity) || other.hasIdentity == _this.hasIdentity)&&(identical(other.authKey, _this.authKey) || other.authKey == _this.authKey)&&(identical(other.ephemeral, _this.ephemeral) || other.ephemeral == _this.ephemeral)&&(identical(other.overridable, _this.overridable) || other.overridable == _this.overridable)&&(identical(other.startError, _this.startError) || other.startError == _this.startError)&&(identical(other.settings, _this.settings) || other.settings == _this.settings)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings)&&(identical(other.legacy, _this.legacy) || other.legacy == _this.legacy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleNode;
  return Object.hashAll([runtimeType,_this.profileId,_this.name,_this.managedId,_this.attached,_this.account,_this.generation,_this.controlUrl,_this.hostname,_this.stateDirMode,_this.started,_this.backendState,_this.loggedOut,_this.hasIdentity,_this.authKey,_this.ephemeral,_this.overridable,_this.startError,_this.settings,const DeepCollectionEquality().hash(_this.warnings),_this.legacy]);
}

@override
String toString() {
  final _this = this as TailscaleNode;
  return 'TailscaleNode(profileId: ${_this.profileId}, name: ${_this.name}, managedId: ${_this.managedId}, attached: ${_this.attached}, account: ${_this.account}, generation: ${_this.generation}, controlUrl: ${_this.controlUrl}, hostname: ${_this.hostname}, stateDirMode: ${_this.stateDirMode}, started: ${_this.started}, backendState: ${_this.backendState}, loggedOut: ${_this.loggedOut}, hasIdentity: ${_this.hasIdentity}, authKey: ${_this.authKey}, ephemeral: ${_this.ephemeral}, overridable: ${_this.overridable}, startError: ${_this.startError}, settings: ${_this.settings}, warnings: ${_this.warnings}, legacy: ${_this.legacy})';
}


}

/// @nodoc
abstract mixin class $TailscaleNodeCopyWith<$Res>  {
  factory $TailscaleNodeCopyWith(TailscaleNode value, $Res Function(TailscaleNode) _then) = _$TailscaleNodeCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId, String name,@JsonKey(name: 'managed-id') String managedId, bool attached, TailscaleAccount? account, int generation,@JsonKey(name: 'control-url') String controlUrl, String hostname,@JsonKey(name: 'state-dir-mode', unknownEnumValue: TailscaleStateDirMode.shared) TailscaleStateDirMode stateDirMode, bool started,@JsonKey(name: 'backend-state', unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState backendState,@JsonKey(name: 'logged-out') bool loggedOut,@JsonKey(name: 'has-identity') bool hasIdentity,@JsonKey(name: 'auth-key') bool authKey, bool ephemeral, bool overridable,@JsonKey(name: 'start-error') TailscaleError? startError, TailscaleSettings settings, List<String> warnings, TailscaleLegacyIdentity? legacy
});


$TailscaleAccountCopyWith<$Res>? get account;$TailscaleErrorCopyWith<$Res>? get startError;$TailscaleSettingsCopyWith<$Res> get settings;$TailscaleLegacyIdentityCopyWith<$Res>? get legacy;

}
/// @nodoc
class _$TailscaleNodeCopyWithImpl<$Res>
    implements $TailscaleNodeCopyWith<$Res> {
  _$TailscaleNodeCopyWithImpl(this._self, this._then);

  final TailscaleNode _self;
  final $Res Function(TailscaleNode) _then;

/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? name = null,Object? managedId = null,Object? attached = null,Object? account = freezed,Object? generation = null,Object? controlUrl = null,Object? hostname = null,Object? stateDirMode = null,Object? started = null,Object? backendState = null,Object? loggedOut = null,Object? hasIdentity = null,Object? authKey = null,Object? ephemeral = null,Object? overridable = null,Object? startError = freezed,Object? settings = null,Object? warnings = null,Object? legacy = freezed,}) {
  return _then(TailscaleNode(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,managedId: null == managedId ? _self.managedId : managedId // ignore: cast_nullable_to_non_nullable
as String,attached: null == attached ? _self.attached : attached // ignore: cast_nullable_to_non_nullable
as bool,account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as TailscaleAccount?,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,hostname: null == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String,stateDirMode: null == stateDirMode ? _self.stateDirMode : stateDirMode // ignore: cast_nullable_to_non_nullable
as TailscaleStateDirMode,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,backendState: null == backendState ? _self.backendState : backendState // ignore: cast_nullable_to_non_nullable
as TailscaleBackendState,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,hasIdentity: null == hasIdentity ? _self.hasIdentity : hasIdentity // ignore: cast_nullable_to_non_nullable
as bool,authKey: null == authKey ? _self.authKey : authKey // ignore: cast_nullable_to_non_nullable
as bool,ephemeral: null == ephemeral ? _self.ephemeral : ephemeral // ignore: cast_nullable_to_non_nullable
as bool,overridable: null == overridable ? _self.overridable : overridable // ignore: cast_nullable_to_non_nullable
as bool,startError: freezed == startError ? _self.startError : startError // ignore: cast_nullable_to_non_nullable
as TailscaleError?,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as TailscaleSettings,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,legacy: freezed == legacy ? _self.legacy : legacy // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyIdentity?,
  ));
}
/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleAccountCopyWith<$Res>? get account {
    if (_self.account == null) {
    return null;
  }

  return $TailscaleAccountCopyWith<$Res>(_self.account!, (value) {
    return _then(_self.copyWith(account: value));
  });
}/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get startError {
    if (_self.startError == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.startError!, (value) {
    return _then(_self.copyWith(startError: value));
  });
}/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleSettingsCopyWith<$Res> get settings {
  
  return $TailscaleSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleLegacyIdentityCopyWith<$Res>? get legacy {
    if (_self.legacy == null) {
    return null;
  }

  return $TailscaleLegacyIdentityCopyWith<$Res>(_self.legacy!, (value) {
    return _then(_self.copyWith(legacy: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleNode].
extension TailscaleNodePatterns on TailscaleNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleNode value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleNode value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId,  String name, @JsonKey(name: 'managed-id')  String managedId,  bool attached,  TailscaleAccount? account,  int generation, @JsonKey(name: 'control-url')  String controlUrl,  String hostname, @JsonKey(name: 'state-dir-mode', unknownEnumValue: TailscaleStateDirMode.shared)  TailscaleStateDirMode stateDirMode,  bool started, @JsonKey(name: 'backend-state', unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState backendState, @JsonKey(name: 'logged-out')  bool loggedOut, @JsonKey(name: 'has-identity')  bool hasIdentity, @JsonKey(name: 'auth-key')  bool authKey,  bool ephemeral,  bool overridable, @JsonKey(name: 'start-error')  TailscaleError? startError,  TailscaleSettings settings,  List<String> warnings,  TailscaleLegacyIdentity? legacy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleNode() when $default != null:
return $default(_that.profileId,_that.name,_that.managedId,_that.attached,_that.account,_that.generation,_that.controlUrl,_that.hostname,_that.stateDirMode,_that.started,_that.backendState,_that.loggedOut,_that.hasIdentity,_that.authKey,_that.ephemeral,_that.overridable,_that.startError,_that.settings,_that.warnings,_that.legacy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId,  String name, @JsonKey(name: 'managed-id')  String managedId,  bool attached,  TailscaleAccount? account,  int generation, @JsonKey(name: 'control-url')  String controlUrl,  String hostname, @JsonKey(name: 'state-dir-mode', unknownEnumValue: TailscaleStateDirMode.shared)  TailscaleStateDirMode stateDirMode,  bool started, @JsonKey(name: 'backend-state', unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState backendState, @JsonKey(name: 'logged-out')  bool loggedOut, @JsonKey(name: 'has-identity')  bool hasIdentity, @JsonKey(name: 'auth-key')  bool authKey,  bool ephemeral,  bool overridable, @JsonKey(name: 'start-error')  TailscaleError? startError,  TailscaleSettings settings,  List<String> warnings,  TailscaleLegacyIdentity? legacy)  $default,) {final _that = this;
switch (_that) {
case _TailscaleNode():
return $default(_that.profileId,_that.name,_that.managedId,_that.attached,_that.account,_that.generation,_that.controlUrl,_that.hostname,_that.stateDirMode,_that.started,_that.backendState,_that.loggedOut,_that.hasIdentity,_that.authKey,_that.ephemeral,_that.overridable,_that.startError,_that.settings,_that.warnings,_that.legacy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'profile-id')  int profileId,  String name, @JsonKey(name: 'managed-id')  String managedId,  bool attached,  TailscaleAccount? account,  int generation, @JsonKey(name: 'control-url')  String controlUrl,  String hostname, @JsonKey(name: 'state-dir-mode', unknownEnumValue: TailscaleStateDirMode.shared)  TailscaleStateDirMode stateDirMode,  bool started, @JsonKey(name: 'backend-state', unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState backendState, @JsonKey(name: 'logged-out')  bool loggedOut, @JsonKey(name: 'has-identity')  bool hasIdentity, @JsonKey(name: 'auth-key')  bool authKey,  bool ephemeral,  bool overridable, @JsonKey(name: 'start-error')  TailscaleError? startError,  TailscaleSettings settings,  List<String> warnings,  TailscaleLegacyIdentity? legacy)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleNode() when $default != null:
return $default(_that.profileId,_that.name,_that.managedId,_that.attached,_that.account,_that.generation,_that.controlUrl,_that.hostname,_that.stateDirMode,_that.started,_that.backendState,_that.loggedOut,_that.hasIdentity,_that.authKey,_that.ephemeral,_that.overridable,_that.startError,_that.settings,_that.warnings,_that.legacy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleNode extends TailscaleNode {
  const _TailscaleNode({@JsonKey(name: 'profile-id') this.profileId = 0, required this.name, @JsonKey(name: 'managed-id') this.managedId = '', this.attached = false, this.account, required this.generation, @JsonKey(name: 'control-url') this.controlUrl = '', this.hostname = '', @JsonKey(name: 'state-dir-mode', unknownEnumValue: TailscaleStateDirMode.shared) this.stateDirMode = TailscaleStateDirMode.shared, this.started = false, @JsonKey(name: 'backend-state', unknownEnumValue: TailscaleBackendState.unknown) this.backendState = TailscaleBackendState.none, @JsonKey(name: 'logged-out') this.loggedOut = false, @JsonKey(name: 'has-identity') this.hasIdentity = false, @JsonKey(name: 'auth-key') this.authKey = false, this.ephemeral = false, this.overridable = false, @JsonKey(name: 'start-error') this.startError, this.settings = const TailscaleSettings(),  List<String> warnings = const [], this.legacy}): _warnings = warnings,super._();
  factory _TailscaleNode.fromJson(Map<String, dynamic> json) => _$TailscaleNodeFromJson(json);

@override@JsonKey(name: 'profile-id') final  int profileId;
@override final  String name;
@override@JsonKey(name: 'managed-id') final  String managedId;
@override@JsonKey() final  bool attached;
@override final  TailscaleAccount? account;
@override final  int generation;
@override@JsonKey(name: 'control-url') final  String controlUrl;
@override@JsonKey() final  String hostname;
@override@JsonKey(name: 'state-dir-mode', unknownEnumValue: TailscaleStateDirMode.shared) final  TailscaleStateDirMode stateDirMode;
@override@JsonKey() final  bool started;
@override@JsonKey(name: 'backend-state', unknownEnumValue: TailscaleBackendState.unknown) final  TailscaleBackendState backendState;
@override@JsonKey(name: 'logged-out') final  bool loggedOut;
@override@JsonKey(name: 'has-identity') final  bool hasIdentity;
@override@JsonKey(name: 'auth-key') final  bool authKey;
@override@JsonKey() final  bool ephemeral;
@override@JsonKey() final  bool overridable;
@override@JsonKey(name: 'start-error') final  TailscaleError? startError;
@override@JsonKey() final  TailscaleSettings settings;
 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

@override final  TailscaleLegacyIdentity? legacy;

/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleNodeCopyWith<_TailscaleNode> get copyWith => __$TailscaleNodeCopyWithImpl<_TailscaleNode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleNodeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleNode&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.name, name) || other.name == name)&&(identical(other.managedId, managedId) || other.managedId == managedId)&&(identical(other.attached, attached) || other.attached == attached)&&(identical(other.account, account) || other.account == account)&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl)&&(identical(other.hostname, hostname) || other.hostname == hostname)&&(identical(other.stateDirMode, stateDirMode) || other.stateDirMode == stateDirMode)&&(identical(other.started, started) || other.started == started)&&(identical(other.backendState, backendState) || other.backendState == backendState)&&(identical(other.loggedOut, loggedOut) || other.loggedOut == loggedOut)&&(identical(other.hasIdentity, hasIdentity) || other.hasIdentity == hasIdentity)&&(identical(other.authKey, authKey) || other.authKey == authKey)&&(identical(other.ephemeral, ephemeral) || other.ephemeral == ephemeral)&&(identical(other.overridable, overridable) || other.overridable == overridable)&&(identical(other.startError, startError) || other.startError == startError)&&(identical(other.settings, settings) || other.settings == settings)&&const DeepCollectionEquality().equals(other.warnings, _warnings)&&(identical(other.legacy, legacy) || other.legacy == legacy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,profileId,name,managedId,attached,account,generation,controlUrl,hostname,stateDirMode,started,backendState,loggedOut,hasIdentity,authKey,ephemeral,overridable,startError,settings,const DeepCollectionEquality().hash(_warnings),legacy]);
}

@override
String toString() {
    return 'TailscaleNode(profileId: $profileId, name: $name, managedId: $managedId, attached: $attached, account: $account, generation: $generation, controlUrl: $controlUrl, hostname: $hostname, stateDirMode: $stateDirMode, started: $started, backendState: $backendState, loggedOut: $loggedOut, hasIdentity: $hasIdentity, authKey: $authKey, ephemeral: $ephemeral, overridable: $overridable, startError: $startError, settings: $settings, warnings: $warnings, legacy: $legacy)';
}


}

/// @nodoc
abstract mixin class _$TailscaleNodeCopyWith<$Res> implements $TailscaleNodeCopyWith<$Res> {
  factory _$TailscaleNodeCopyWith(_TailscaleNode value, $Res Function(_TailscaleNode) _then) = __$TailscaleNodeCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId, String name,@JsonKey(name: 'managed-id') String managedId, bool attached, TailscaleAccount? account, int generation,@JsonKey(name: 'control-url') String controlUrl, String hostname,@JsonKey(name: 'state-dir-mode', unknownEnumValue: TailscaleStateDirMode.shared) TailscaleStateDirMode stateDirMode, bool started,@JsonKey(name: 'backend-state', unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState backendState,@JsonKey(name: 'logged-out') bool loggedOut,@JsonKey(name: 'has-identity') bool hasIdentity,@JsonKey(name: 'auth-key') bool authKey, bool ephemeral, bool overridable,@JsonKey(name: 'start-error') TailscaleError? startError, TailscaleSettings settings, List<String> warnings, TailscaleLegacyIdentity? legacy
});


@override $TailscaleAccountCopyWith<$Res>? get account;@override $TailscaleErrorCopyWith<$Res>? get startError;@override $TailscaleSettingsCopyWith<$Res> get settings;@override $TailscaleLegacyIdentityCopyWith<$Res>? get legacy;

}
/// @nodoc
class __$TailscaleNodeCopyWithImpl<$Res>
    implements _$TailscaleNodeCopyWith<$Res> {
  __$TailscaleNodeCopyWithImpl(this._self, this._then);

  final _TailscaleNode _self;
  final $Res Function(_TailscaleNode) _then;

/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? name = null,Object? managedId = null,Object? attached = null,Object? account = freezed,Object? generation = null,Object? controlUrl = null,Object? hostname = null,Object? stateDirMode = null,Object? started = null,Object? backendState = null,Object? loggedOut = null,Object? hasIdentity = null,Object? authKey = null,Object? ephemeral = null,Object? overridable = null,Object? startError = freezed,Object? settings = null,Object? warnings = null,Object? legacy = freezed,}) {
  return _then(_TailscaleNode(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,managedId: null == managedId ? _self.managedId : managedId // ignore: cast_nullable_to_non_nullable
as String,attached: null == attached ? _self.attached : attached // ignore: cast_nullable_to_non_nullable
as bool,account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as TailscaleAccount?,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,hostname: null == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String,stateDirMode: null == stateDirMode ? _self.stateDirMode : stateDirMode // ignore: cast_nullable_to_non_nullable
as TailscaleStateDirMode,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,backendState: null == backendState ? _self.backendState : backendState // ignore: cast_nullable_to_non_nullable
as TailscaleBackendState,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,hasIdentity: null == hasIdentity ? _self.hasIdentity : hasIdentity // ignore: cast_nullable_to_non_nullable
as bool,authKey: null == authKey ? _self.authKey : authKey // ignore: cast_nullable_to_non_nullable
as bool,ephemeral: null == ephemeral ? _self.ephemeral : ephemeral // ignore: cast_nullable_to_non_nullable
as bool,overridable: null == overridable ? _self.overridable : overridable // ignore: cast_nullable_to_non_nullable
as bool,startError: freezed == startError ? _self.startError : startError // ignore: cast_nullable_to_non_nullable
as TailscaleError?,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as TailscaleSettings,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,legacy: freezed == legacy ? _self.legacy : legacy // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyIdentity?,
  ));
}

/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleAccountCopyWith<$Res>? get account {
    if (_self.account == null) {
    return null;
  }

  return $TailscaleAccountCopyWith<$Res>(_self.account!, (value) {
    return _then(_self.copyWith(account: value));
  });
}/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get startError {
    if (_self.startError == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.startError!, (value) {
    return _then(_self.copyWith(startError: value));
  });
}/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleSettingsCopyWith<$Res> get settings {
  
  return $TailscaleSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}/// Create a copy of TailscaleNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleLegacyIdentityCopyWith<$Res>? get legacy {
    if (_self.legacy == null) {
    return null;
  }

  return $TailscaleLegacyIdentityCopyWith<$Res>(_self.legacy!, (value) {
    return _then(_self.copyWith(legacy: value));
  });
}
}


/// @nodoc
mixin _$TailscaleAccount {

@JsonKey(name: 'user-id') String get userId;@JsonKey(name: 'login-name') String get loginName;@JsonKey(name: 'display-name') String get displayName; String get tailnet;@JsonKey(name: 'control-url') String get controlUrl;
/// Create a copy of TailscaleAccount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleAccountCopyWith<TailscaleAccount> get copyWith => _$TailscaleAccountCopyWithImpl<TailscaleAccount>(this as TailscaleAccount, _$identity);

  /// Serializes this TailscaleAccount to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleAccount;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleAccount&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.loginName, _this.loginName) || other.loginName == _this.loginName)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.tailnet, _this.tailnet) || other.tailnet == _this.tailnet)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleAccount;
  return Object.hash(runtimeType,_this.userId,_this.loginName,_this.displayName,_this.tailnet,_this.controlUrl);
}

@override
String toString() {
  final _this = this as TailscaleAccount;
  return 'TailscaleAccount(userId: ${_this.userId}, loginName: ${_this.loginName}, displayName: ${_this.displayName}, tailnet: ${_this.tailnet}, controlUrl: ${_this.controlUrl})';
}


}

/// @nodoc
abstract mixin class $TailscaleAccountCopyWith<$Res>  {
  factory $TailscaleAccountCopyWith(TailscaleAccount value, $Res Function(TailscaleAccount) _then) = _$TailscaleAccountCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user-id') String userId,@JsonKey(name: 'login-name') String loginName,@JsonKey(name: 'display-name') String displayName, String tailnet,@JsonKey(name: 'control-url') String controlUrl
});




}
/// @nodoc
class _$TailscaleAccountCopyWithImpl<$Res>
    implements $TailscaleAccountCopyWith<$Res> {
  _$TailscaleAccountCopyWithImpl(this._self, this._then);

  final TailscaleAccount _self;
  final $Res Function(TailscaleAccount) _then;

/// Create a copy of TailscaleAccount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? loginName = null,Object? displayName = null,Object? tailnet = null,Object? controlUrl = null,}) {
  return _then(TailscaleAccount(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,tailnet: null == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleAccount].
extension TailscaleAccountPatterns on TailscaleAccount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleAccount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleAccount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleAccount value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleAccount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleAccount value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleAccount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user-id')  String userId, @JsonKey(name: 'login-name')  String loginName, @JsonKey(name: 'display-name')  String displayName,  String tailnet, @JsonKey(name: 'control-url')  String controlUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleAccount() when $default != null:
return $default(_that.userId,_that.loginName,_that.displayName,_that.tailnet,_that.controlUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user-id')  String userId, @JsonKey(name: 'login-name')  String loginName, @JsonKey(name: 'display-name')  String displayName,  String tailnet, @JsonKey(name: 'control-url')  String controlUrl)  $default,) {final _that = this;
switch (_that) {
case _TailscaleAccount():
return $default(_that.userId,_that.loginName,_that.displayName,_that.tailnet,_that.controlUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user-id')  String userId, @JsonKey(name: 'login-name')  String loginName, @JsonKey(name: 'display-name')  String displayName,  String tailnet, @JsonKey(name: 'control-url')  String controlUrl)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleAccount() when $default != null:
return $default(_that.userId,_that.loginName,_that.displayName,_that.tailnet,_that.controlUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleAccount extends TailscaleAccount {
  const _TailscaleAccount({@JsonKey(name: 'user-id') this.userId = '', @JsonKey(name: 'login-name') this.loginName = '', @JsonKey(name: 'display-name') this.displayName = '', this.tailnet = '', @JsonKey(name: 'control-url') this.controlUrl = ''}): super._();
  factory _TailscaleAccount.fromJson(Map<String, dynamic> json) => _$TailscaleAccountFromJson(json);

@override@JsonKey(name: 'user-id') final  String userId;
@override@JsonKey(name: 'login-name') final  String loginName;
@override@JsonKey(name: 'display-name') final  String displayName;
@override@JsonKey() final  String tailnet;
@override@JsonKey(name: 'control-url') final  String controlUrl;

/// Create a copy of TailscaleAccount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleAccountCopyWith<_TailscaleAccount> get copyWith => __$TailscaleAccountCopyWithImpl<_TailscaleAccount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleAccountToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleAccount&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.loginName, loginName) || other.loginName == loginName)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.tailnet, tailnet) || other.tailnet == tailnet)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,userId,loginName,displayName,tailnet,controlUrl);
}

@override
String toString() {
    return 'TailscaleAccount(userId: $userId, loginName: $loginName, displayName: $displayName, tailnet: $tailnet, controlUrl: $controlUrl)';
}


}

/// @nodoc
abstract mixin class _$TailscaleAccountCopyWith<$Res> implements $TailscaleAccountCopyWith<$Res> {
  factory _$TailscaleAccountCopyWith(_TailscaleAccount value, $Res Function(_TailscaleAccount) _then) = __$TailscaleAccountCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user-id') String userId,@JsonKey(name: 'login-name') String loginName,@JsonKey(name: 'display-name') String displayName, String tailnet,@JsonKey(name: 'control-url') String controlUrl
});




}
/// @nodoc
class __$TailscaleAccountCopyWithImpl<$Res>
    implements _$TailscaleAccountCopyWith<$Res> {
  __$TailscaleAccountCopyWithImpl(this._self, this._then);

  final _TailscaleAccount _self;
  final $Res Function(_TailscaleAccount) _then;

/// Create a copy of TailscaleAccount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? loginName = null,Object? displayName = null,Object? tailnet = null,Object? controlUrl = null,}) {
  return _then(_TailscaleAccount(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,tailnet: null == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TailscaleNodeRef {

 String get name;@JsonKey(name: 'managed-id', includeIfNull: false) String? get managedId; int get generation;
/// Create a copy of TailscaleNodeRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleNodeRefCopyWith<TailscaleNodeRef> get copyWith => _$TailscaleNodeRefCopyWithImpl<TailscaleNodeRef>(this as TailscaleNodeRef, _$identity);

  /// Serializes this TailscaleNodeRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleNodeRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleNodeRef&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.managedId, _this.managedId) || other.managedId == _this.managedId)&&(identical(other.generation, _this.generation) || other.generation == _this.generation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleNodeRef;
  return Object.hash(runtimeType,_this.name,_this.managedId,_this.generation);
}

@override
String toString() {
  final _this = this as TailscaleNodeRef;
  return 'TailscaleNodeRef(name: ${_this.name}, managedId: ${_this.managedId}, generation: ${_this.generation})';
}


}

/// @nodoc
abstract mixin class $TailscaleNodeRefCopyWith<$Res>  {
  factory $TailscaleNodeRefCopyWith(TailscaleNodeRef value, $Res Function(TailscaleNodeRef) _then) = _$TailscaleNodeRefCopyWithImpl;
@useResult
$Res call({
 String name,@JsonKey(name: 'managed-id', includeIfNull: false) String? managedId, int generation
});




}
/// @nodoc
class _$TailscaleNodeRefCopyWithImpl<$Res>
    implements $TailscaleNodeRefCopyWith<$Res> {
  _$TailscaleNodeRefCopyWithImpl(this._self, this._then);

  final TailscaleNodeRef _self;
  final $Res Function(TailscaleNodeRef) _then;

/// Create a copy of TailscaleNodeRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? managedId = freezed,Object? generation = null,}) {
  return _then(TailscaleNodeRef(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,managedId: freezed == managedId ? _self.managedId : managedId // ignore: cast_nullable_to_non_nullable
as String?,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleNodeRef].
extension TailscaleNodeRefPatterns on TailscaleNodeRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleNodeRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleNodeRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleNodeRef value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleNodeRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleNodeRef value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleNodeRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name, @JsonKey(name: 'managed-id', includeIfNull: false)  String? managedId,  int generation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleNodeRef() when $default != null:
return $default(_that.name,_that.managedId,_that.generation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name, @JsonKey(name: 'managed-id', includeIfNull: false)  String? managedId,  int generation)  $default,) {final _that = this;
switch (_that) {
case _TailscaleNodeRef():
return $default(_that.name,_that.managedId,_that.generation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name, @JsonKey(name: 'managed-id', includeIfNull: false)  String? managedId,  int generation)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleNodeRef() when $default != null:
return $default(_that.name,_that.managedId,_that.generation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleNodeRef implements TailscaleNodeRef {
  const _TailscaleNodeRef({required this.name, @JsonKey(name: 'managed-id', includeIfNull: false) this.managedId, required this.generation});
  factory _TailscaleNodeRef.fromJson(Map<String, dynamic> json) => _$TailscaleNodeRefFromJson(json);

@override final  String name;
@override@JsonKey(name: 'managed-id', includeIfNull: false) final  String? managedId;
@override final  int generation;

/// Create a copy of TailscaleNodeRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleNodeRefCopyWith<_TailscaleNodeRef> get copyWith => __$TailscaleNodeRefCopyWithImpl<_TailscaleNodeRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleNodeRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleNodeRef&&(identical(other.name, name) || other.name == name)&&(identical(other.managedId, managedId) || other.managedId == managedId)&&(identical(other.generation, generation) || other.generation == generation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,managedId,generation);
}

@override
String toString() {
    return 'TailscaleNodeRef(name: $name, managedId: $managedId, generation: $generation)';
}


}

/// @nodoc
abstract mixin class _$TailscaleNodeRefCopyWith<$Res> implements $TailscaleNodeRefCopyWith<$Res> {
  factory _$TailscaleNodeRefCopyWith(_TailscaleNodeRef value, $Res Function(_TailscaleNodeRef) _then) = __$TailscaleNodeRefCopyWithImpl;
@override @useResult
$Res call({
 String name,@JsonKey(name: 'managed-id', includeIfNull: false) String? managedId, int generation
});




}
/// @nodoc
class __$TailscaleNodeRefCopyWithImpl<$Res>
    implements _$TailscaleNodeRefCopyWith<$Res> {
  __$TailscaleNodeRefCopyWithImpl(this._self, this._then);

  final _TailscaleNodeRef _self;
  final $Res Function(_TailscaleNodeRef) _then;

/// Create a copy of TailscaleNodeRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? managedId = freezed,Object? generation = null,}) {
  return _then(_TailscaleNodeRef(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,managedId: freezed == managedId ? _self.managedId : managedId // ignore: cast_nullable_to_non_nullable
as String?,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TailscaleLegacyMigration {

 String get fingerprint;@JsonKey(name: 'profile-id') int get profileId; String get name;@JsonKey(name: 'control-url') String get controlUrl;
/// Create a copy of TailscaleLegacyMigration
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleLegacyMigrationCopyWith<TailscaleLegacyMigration> get copyWith => _$TailscaleLegacyMigrationCopyWithImpl<TailscaleLegacyMigration>(this as TailscaleLegacyMigration, _$identity);

  /// Serializes this TailscaleLegacyMigration to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleLegacyMigration;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleLegacyMigration&&(identical(other.fingerprint, _this.fingerprint) || other.fingerprint == _this.fingerprint)&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleLegacyMigration;
  return Object.hash(runtimeType,_this.fingerprint,_this.profileId,_this.name,_this.controlUrl);
}

@override
String toString() {
  final _this = this as TailscaleLegacyMigration;
  return 'TailscaleLegacyMigration(fingerprint: ${_this.fingerprint}, profileId: ${_this.profileId}, name: ${_this.name}, controlUrl: ${_this.controlUrl})';
}


}

/// @nodoc
abstract mixin class $TailscaleLegacyMigrationCopyWith<$Res>  {
  factory $TailscaleLegacyMigrationCopyWith(TailscaleLegacyMigration value, $Res Function(TailscaleLegacyMigration) _then) = _$TailscaleLegacyMigrationCopyWithImpl;
@useResult
$Res call({
 String fingerprint,@JsonKey(name: 'profile-id') int profileId, String name,@JsonKey(name: 'control-url') String controlUrl
});




}
/// @nodoc
class _$TailscaleLegacyMigrationCopyWithImpl<$Res>
    implements $TailscaleLegacyMigrationCopyWith<$Res> {
  _$TailscaleLegacyMigrationCopyWithImpl(this._self, this._then);

  final TailscaleLegacyMigration _self;
  final $Res Function(TailscaleLegacyMigration) _then;

/// Create a copy of TailscaleLegacyMigration
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fingerprint = null,Object? profileId = null,Object? name = null,Object? controlUrl = null,}) {
  return _then(TailscaleLegacyMigration(
fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleLegacyMigration].
extension TailscaleLegacyMigrationPatterns on TailscaleLegacyMigration {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleLegacyMigration value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleLegacyMigration() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleLegacyMigration value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleLegacyMigration():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleLegacyMigration value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleLegacyMigration() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fingerprint, @JsonKey(name: 'profile-id')  int profileId,  String name, @JsonKey(name: 'control-url')  String controlUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleLegacyMigration() when $default != null:
return $default(_that.fingerprint,_that.profileId,_that.name,_that.controlUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fingerprint, @JsonKey(name: 'profile-id')  int profileId,  String name, @JsonKey(name: 'control-url')  String controlUrl)  $default,) {final _that = this;
switch (_that) {
case _TailscaleLegacyMigration():
return $default(_that.fingerprint,_that.profileId,_that.name,_that.controlUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fingerprint, @JsonKey(name: 'profile-id')  int profileId,  String name, @JsonKey(name: 'control-url')  String controlUrl)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleLegacyMigration() when $default != null:
return $default(_that.fingerprint,_that.profileId,_that.name,_that.controlUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleLegacyMigration implements TailscaleLegacyMigration {
  const _TailscaleLegacyMigration({required this.fingerprint, @JsonKey(name: 'profile-id') this.profileId = 0, this.name = '', @JsonKey(name: 'control-url') this.controlUrl = ''});
  factory _TailscaleLegacyMigration.fromJson(Map<String, dynamic> json) => _$TailscaleLegacyMigrationFromJson(json);

@override final  String fingerprint;
@override@JsonKey(name: 'profile-id') final  int profileId;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'control-url') final  String controlUrl;

/// Create a copy of TailscaleLegacyMigration
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleLegacyMigrationCopyWith<_TailscaleLegacyMigration> get copyWith => __$TailscaleLegacyMigrationCopyWithImpl<_TailscaleLegacyMigration>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleLegacyMigrationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleLegacyMigration&&(identical(other.fingerprint, fingerprint) || other.fingerprint == fingerprint)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.name, name) || other.name == name)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,fingerprint,profileId,name,controlUrl);
}

@override
String toString() {
    return 'TailscaleLegacyMigration(fingerprint: $fingerprint, profileId: $profileId, name: $name, controlUrl: $controlUrl)';
}


}

/// @nodoc
abstract mixin class _$TailscaleLegacyMigrationCopyWith<$Res> implements $TailscaleLegacyMigrationCopyWith<$Res> {
  factory _$TailscaleLegacyMigrationCopyWith(_TailscaleLegacyMigration value, $Res Function(_TailscaleLegacyMigration) _then) = __$TailscaleLegacyMigrationCopyWithImpl;
@override @useResult
$Res call({
 String fingerprint,@JsonKey(name: 'profile-id') int profileId, String name,@JsonKey(name: 'control-url') String controlUrl
});




}
/// @nodoc
class __$TailscaleLegacyMigrationCopyWithImpl<$Res>
    implements _$TailscaleLegacyMigrationCopyWith<$Res> {
  __$TailscaleLegacyMigrationCopyWithImpl(this._self, this._then);

  final _TailscaleLegacyMigration _self;
  final $Res Function(_TailscaleLegacyMigration) _then;

/// Create a copy of TailscaleLegacyMigration
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fingerprint = null,Object? profileId = null,Object? name = null,Object? controlUrl = null,}) {
  return _then(_TailscaleLegacyMigration(
fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TailscaleLegacyIdentity {

@JsonKey(name: 'login-name') String get loginName;@JsonKey(name: 'display-name') String get displayName; String get tailnet;@JsonKey(name: 'control-url') String get controlUrl; String get fingerprint;@JsonKey(name: 'migrated-to') TailscaleLegacyMigration? get migratedTo;@JsonKey(unknownEnumValue: TailscaleLegacyEligibility.unconfirmed) TailscaleLegacyEligibility get eligibility;@JsonKey(name: 'offer-token') String? get offerToken;
/// Create a copy of TailscaleLegacyIdentity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleLegacyIdentityCopyWith<TailscaleLegacyIdentity> get copyWith => _$TailscaleLegacyIdentityCopyWithImpl<TailscaleLegacyIdentity>(this as TailscaleLegacyIdentity, _$identity);

  /// Serializes this TailscaleLegacyIdentity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleLegacyIdentity;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleLegacyIdentity&&(identical(other.loginName, _this.loginName) || other.loginName == _this.loginName)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.tailnet, _this.tailnet) || other.tailnet == _this.tailnet)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl)&&(identical(other.fingerprint, _this.fingerprint) || other.fingerprint == _this.fingerprint)&&(identical(other.migratedTo, _this.migratedTo) || other.migratedTo == _this.migratedTo)&&(identical(other.eligibility, _this.eligibility) || other.eligibility == _this.eligibility)&&(identical(other.offerToken, _this.offerToken) || other.offerToken == _this.offerToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleLegacyIdentity;
  return Object.hash(runtimeType,_this.loginName,_this.displayName,_this.tailnet,_this.controlUrl,_this.fingerprint,_this.migratedTo,_this.eligibility,_this.offerToken);
}

@override
String toString() {
  final _this = this as TailscaleLegacyIdentity;
  return 'TailscaleLegacyIdentity(loginName: ${_this.loginName}, displayName: ${_this.displayName}, tailnet: ${_this.tailnet}, controlUrl: ${_this.controlUrl}, fingerprint: ${_this.fingerprint}, migratedTo: ${_this.migratedTo}, eligibility: ${_this.eligibility}, offerToken: ${_this.offerToken})';
}


}

/// @nodoc
abstract mixin class $TailscaleLegacyIdentityCopyWith<$Res>  {
  factory $TailscaleLegacyIdentityCopyWith(TailscaleLegacyIdentity value, $Res Function(TailscaleLegacyIdentity) _then) = _$TailscaleLegacyIdentityCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'login-name') String loginName,@JsonKey(name: 'display-name') String displayName, String tailnet,@JsonKey(name: 'control-url') String controlUrl, String fingerprint,@JsonKey(name: 'migrated-to') TailscaleLegacyMigration? migratedTo,@JsonKey(unknownEnumValue: TailscaleLegacyEligibility.unconfirmed) TailscaleLegacyEligibility eligibility,@JsonKey(name: 'offer-token') String? offerToken
});


$TailscaleLegacyMigrationCopyWith<$Res>? get migratedTo;

}
/// @nodoc
class _$TailscaleLegacyIdentityCopyWithImpl<$Res>
    implements $TailscaleLegacyIdentityCopyWith<$Res> {
  _$TailscaleLegacyIdentityCopyWithImpl(this._self, this._then);

  final TailscaleLegacyIdentity _self;
  final $Res Function(TailscaleLegacyIdentity) _then;

/// Create a copy of TailscaleLegacyIdentity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loginName = null,Object? displayName = null,Object? tailnet = null,Object? controlUrl = null,Object? fingerprint = null,Object? migratedTo = freezed,Object? eligibility = null,Object? offerToken = freezed,}) {
  return _then(TailscaleLegacyIdentity(
loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,tailnet: null == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,migratedTo: freezed == migratedTo ? _self.migratedTo : migratedTo // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyMigration?,eligibility: null == eligibility ? _self.eligibility : eligibility // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyEligibility,offerToken: freezed == offerToken ? _self.offerToken : offerToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of TailscaleLegacyIdentity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleLegacyMigrationCopyWith<$Res>? get migratedTo {
    if (_self.migratedTo == null) {
    return null;
  }

  return $TailscaleLegacyMigrationCopyWith<$Res>(_self.migratedTo!, (value) {
    return _then(_self.copyWith(migratedTo: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleLegacyIdentity].
extension TailscaleLegacyIdentityPatterns on TailscaleLegacyIdentity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleLegacyIdentity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleLegacyIdentity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleLegacyIdentity value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleLegacyIdentity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleLegacyIdentity value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleLegacyIdentity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'login-name')  String loginName, @JsonKey(name: 'display-name')  String displayName,  String tailnet, @JsonKey(name: 'control-url')  String controlUrl,  String fingerprint, @JsonKey(name: 'migrated-to')  TailscaleLegacyMigration? migratedTo, @JsonKey(unknownEnumValue: TailscaleLegacyEligibility.unconfirmed)  TailscaleLegacyEligibility eligibility, @JsonKey(name: 'offer-token')  String? offerToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleLegacyIdentity() when $default != null:
return $default(_that.loginName,_that.displayName,_that.tailnet,_that.controlUrl,_that.fingerprint,_that.migratedTo,_that.eligibility,_that.offerToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'login-name')  String loginName, @JsonKey(name: 'display-name')  String displayName,  String tailnet, @JsonKey(name: 'control-url')  String controlUrl,  String fingerprint, @JsonKey(name: 'migrated-to')  TailscaleLegacyMigration? migratedTo, @JsonKey(unknownEnumValue: TailscaleLegacyEligibility.unconfirmed)  TailscaleLegacyEligibility eligibility, @JsonKey(name: 'offer-token')  String? offerToken)  $default,) {final _that = this;
switch (_that) {
case _TailscaleLegacyIdentity():
return $default(_that.loginName,_that.displayName,_that.tailnet,_that.controlUrl,_that.fingerprint,_that.migratedTo,_that.eligibility,_that.offerToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'login-name')  String loginName, @JsonKey(name: 'display-name')  String displayName,  String tailnet, @JsonKey(name: 'control-url')  String controlUrl,  String fingerprint, @JsonKey(name: 'migrated-to')  TailscaleLegacyMigration? migratedTo, @JsonKey(unknownEnumValue: TailscaleLegacyEligibility.unconfirmed)  TailscaleLegacyEligibility eligibility, @JsonKey(name: 'offer-token')  String? offerToken)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleLegacyIdentity() when $default != null:
return $default(_that.loginName,_that.displayName,_that.tailnet,_that.controlUrl,_that.fingerprint,_that.migratedTo,_that.eligibility,_that.offerToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleLegacyIdentity implements TailscaleLegacyIdentity {
  const _TailscaleLegacyIdentity({@JsonKey(name: 'login-name') this.loginName = '', @JsonKey(name: 'display-name') this.displayName = '', this.tailnet = '', @JsonKey(name: 'control-url') this.controlUrl = '', this.fingerprint = '', @JsonKey(name: 'migrated-to') this.migratedTo, @JsonKey(unknownEnumValue: TailscaleLegacyEligibility.unconfirmed) this.eligibility = TailscaleLegacyEligibility.unconfirmed, @JsonKey(name: 'offer-token') this.offerToken});
  factory _TailscaleLegacyIdentity.fromJson(Map<String, dynamic> json) => _$TailscaleLegacyIdentityFromJson(json);

@override@JsonKey(name: 'login-name') final  String loginName;
@override@JsonKey(name: 'display-name') final  String displayName;
@override@JsonKey() final  String tailnet;
@override@JsonKey(name: 'control-url') final  String controlUrl;
@override@JsonKey() final  String fingerprint;
@override@JsonKey(name: 'migrated-to') final  TailscaleLegacyMigration? migratedTo;
@override@JsonKey(unknownEnumValue: TailscaleLegacyEligibility.unconfirmed) final  TailscaleLegacyEligibility eligibility;
@override@JsonKey(name: 'offer-token') final  String? offerToken;

/// Create a copy of TailscaleLegacyIdentity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleLegacyIdentityCopyWith<_TailscaleLegacyIdentity> get copyWith => __$TailscaleLegacyIdentityCopyWithImpl<_TailscaleLegacyIdentity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleLegacyIdentityToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleLegacyIdentity&&(identical(other.loginName, loginName) || other.loginName == loginName)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.tailnet, tailnet) || other.tailnet == tailnet)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl)&&(identical(other.fingerprint, fingerprint) || other.fingerprint == fingerprint)&&(identical(other.migratedTo, migratedTo) || other.migratedTo == migratedTo)&&(identical(other.eligibility, eligibility) || other.eligibility == eligibility)&&(identical(other.offerToken, offerToken) || other.offerToken == offerToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,loginName,displayName,tailnet,controlUrl,fingerprint,migratedTo,eligibility,offerToken);
}

@override
String toString() {
    return 'TailscaleLegacyIdentity(loginName: $loginName, displayName: $displayName, tailnet: $tailnet, controlUrl: $controlUrl, fingerprint: $fingerprint, migratedTo: $migratedTo, eligibility: $eligibility, offerToken: $offerToken)';
}


}

/// @nodoc
abstract mixin class _$TailscaleLegacyIdentityCopyWith<$Res> implements $TailscaleLegacyIdentityCopyWith<$Res> {
  factory _$TailscaleLegacyIdentityCopyWith(_TailscaleLegacyIdentity value, $Res Function(_TailscaleLegacyIdentity) _then) = __$TailscaleLegacyIdentityCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'login-name') String loginName,@JsonKey(name: 'display-name') String displayName, String tailnet,@JsonKey(name: 'control-url') String controlUrl, String fingerprint,@JsonKey(name: 'migrated-to') TailscaleLegacyMigration? migratedTo,@JsonKey(unknownEnumValue: TailscaleLegacyEligibility.unconfirmed) TailscaleLegacyEligibility eligibility,@JsonKey(name: 'offer-token') String? offerToken
});


@override $TailscaleLegacyMigrationCopyWith<$Res>? get migratedTo;

}
/// @nodoc
class __$TailscaleLegacyIdentityCopyWithImpl<$Res>
    implements _$TailscaleLegacyIdentityCopyWith<$Res> {
  __$TailscaleLegacyIdentityCopyWithImpl(this._self, this._then);

  final _TailscaleLegacyIdentity _self;
  final $Res Function(_TailscaleLegacyIdentity) _then;

/// Create a copy of TailscaleLegacyIdentity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loginName = null,Object? displayName = null,Object? tailnet = null,Object? controlUrl = null,Object? fingerprint = null,Object? migratedTo = freezed,Object? eligibility = null,Object? offerToken = freezed,}) {
  return _then(_TailscaleLegacyIdentity(
loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,tailnet: null == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,migratedTo: freezed == migratedTo ? _self.migratedTo : migratedTo // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyMigration?,eligibility: null == eligibility ? _self.eligibility : eligibility // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyEligibility,offerToken: freezed == offerToken ? _self.offerToken : offerToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of TailscaleLegacyIdentity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleLegacyMigrationCopyWith<$Res>? get migratedTo {
    if (_self.migratedTo == null) {
    return null;
  }

  return $TailscaleLegacyMigrationCopyWith<$Res>(_self.migratedTo!, (value) {
    return _then(_self.copyWith(migratedTo: value));
  });
}
}


/// @nodoc
mixin _$TailscaleMigrateResult {

 int get generation;@JsonKey(unknownEnumValue: TailscaleMigrateOutcome.unknown) TailscaleMigrateOutcome get outcome; TailscaleLegacyMigration get migration; TailscaleNode get node;@JsonKey(name: 'reapply-required') bool get reapplyRequired;@JsonKey(name: 'target-untouched') bool get targetUntouched;@JsonKey(name: 'archive-intact') bool get archiveIntact;@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) TailscaleMigrateStage? get stage; TailscaleError? get error;
/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleMigrateResultCopyWith<TailscaleMigrateResult> get copyWith => _$TailscaleMigrateResultCopyWithImpl<TailscaleMigrateResult>(this as TailscaleMigrateResult, _$identity);

  /// Serializes this TailscaleMigrateResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleMigrateResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleMigrateResult&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.migration, _this.migration) || other.migration == _this.migration)&&(identical(other.node, _this.node) || other.node == _this.node)&&(identical(other.reapplyRequired, _this.reapplyRequired) || other.reapplyRequired == _this.reapplyRequired)&&(identical(other.targetUntouched, _this.targetUntouched) || other.targetUntouched == _this.targetUntouched)&&(identical(other.archiveIntact, _this.archiveIntact) || other.archiveIntact == _this.archiveIntact)&&(identical(other.stage, _this.stage) || other.stage == _this.stage)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleMigrateResult;
  return Object.hash(runtimeType,_this.generation,_this.outcome,_this.migration,_this.node,_this.reapplyRequired,_this.targetUntouched,_this.archiveIntact,_this.stage,_this.error);
}

@override
String toString() {
  final _this = this as TailscaleMigrateResult;
  return 'TailscaleMigrateResult(generation: ${_this.generation}, outcome: ${_this.outcome}, migration: ${_this.migration}, node: ${_this.node}, reapplyRequired: ${_this.reapplyRequired}, targetUntouched: ${_this.targetUntouched}, archiveIntact: ${_this.archiveIntact}, stage: ${_this.stage}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $TailscaleMigrateResultCopyWith<$Res>  {
  factory $TailscaleMigrateResultCopyWith(TailscaleMigrateResult value, $Res Function(TailscaleMigrateResult) _then) = _$TailscaleMigrateResultCopyWithImpl;
@useResult
$Res call({
 int generation,@JsonKey(unknownEnumValue: TailscaleMigrateOutcome.unknown) TailscaleMigrateOutcome outcome, TailscaleLegacyMigration migration, TailscaleNode node,@JsonKey(name: 'reapply-required') bool reapplyRequired,@JsonKey(name: 'target-untouched') bool targetUntouched,@JsonKey(name: 'archive-intact') bool archiveIntact,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) TailscaleMigrateStage? stage, TailscaleError? error
});


$TailscaleLegacyMigrationCopyWith<$Res> get migration;$TailscaleNodeCopyWith<$Res> get node;$TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$TailscaleMigrateResultCopyWithImpl<$Res>
    implements $TailscaleMigrateResultCopyWith<$Res> {
  _$TailscaleMigrateResultCopyWithImpl(this._self, this._then);

  final TailscaleMigrateResult _self;
  final $Res Function(TailscaleMigrateResult) _then;

/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generation = null,Object? outcome = null,Object? migration = null,Object? node = null,Object? reapplyRequired = null,Object? targetUntouched = null,Object? archiveIntact = null,Object? stage = freezed,Object? error = freezed,}) {
  return _then(TailscaleMigrateResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as TailscaleMigrateOutcome,migration: null == migration ? _self.migration : migration // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyMigration,node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as TailscaleNode,reapplyRequired: null == reapplyRequired ? _self.reapplyRequired : reapplyRequired // ignore: cast_nullable_to_non_nullable
as bool,targetUntouched: null == targetUntouched ? _self.targetUntouched : targetUntouched // ignore: cast_nullable_to_non_nullable
as bool,archiveIntact: null == archiveIntact ? _self.archiveIntact : archiveIntact // ignore: cast_nullable_to_non_nullable
as bool,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as TailscaleMigrateStage?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}
/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleLegacyMigrationCopyWith<$Res> get migration {
  
  return $TailscaleLegacyMigrationCopyWith<$Res>(_self.migration, (value) {
    return _then(_self.copyWith(migration: value));
  });
}/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleNodeCopyWith<$Res> get node {
  
  return $TailscaleNodeCopyWith<$Res>(_self.node, (value) {
    return _then(_self.copyWith(node: value));
  });
}/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleMigrateResult].
extension TailscaleMigrateResultPatterns on TailscaleMigrateResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleMigrateResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleMigrateResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleMigrateResult value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleMigrateResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleMigrateResult value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleMigrateResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int generation, @JsonKey(unknownEnumValue: TailscaleMigrateOutcome.unknown)  TailscaleMigrateOutcome outcome,  TailscaleLegacyMigration migration,  TailscaleNode node, @JsonKey(name: 'reapply-required')  bool reapplyRequired, @JsonKey(name: 'target-untouched')  bool targetUntouched, @JsonKey(name: 'archive-intact')  bool archiveIntact, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  TailscaleMigrateStage? stage,  TailscaleError? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleMigrateResult() when $default != null:
return $default(_that.generation,_that.outcome,_that.migration,_that.node,_that.reapplyRequired,_that.targetUntouched,_that.archiveIntact,_that.stage,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int generation, @JsonKey(unknownEnumValue: TailscaleMigrateOutcome.unknown)  TailscaleMigrateOutcome outcome,  TailscaleLegacyMigration migration,  TailscaleNode node, @JsonKey(name: 'reapply-required')  bool reapplyRequired, @JsonKey(name: 'target-untouched')  bool targetUntouched, @JsonKey(name: 'archive-intact')  bool archiveIntact, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  TailscaleMigrateStage? stage,  TailscaleError? error)  $default,) {final _that = this;
switch (_that) {
case _TailscaleMigrateResult():
return $default(_that.generation,_that.outcome,_that.migration,_that.node,_that.reapplyRequired,_that.targetUntouched,_that.archiveIntact,_that.stage,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int generation, @JsonKey(unknownEnumValue: TailscaleMigrateOutcome.unknown)  TailscaleMigrateOutcome outcome,  TailscaleLegacyMigration migration,  TailscaleNode node, @JsonKey(name: 'reapply-required')  bool reapplyRequired, @JsonKey(name: 'target-untouched')  bool targetUntouched, @JsonKey(name: 'archive-intact')  bool archiveIntact, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  TailscaleMigrateStage? stage,  TailscaleError? error)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleMigrateResult() when $default != null:
return $default(_that.generation,_that.outcome,_that.migration,_that.node,_that.reapplyRequired,_that.targetUntouched,_that.archiveIntact,_that.stage,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleMigrateResult implements TailscaleMigrateResult {
  const _TailscaleMigrateResult({required this.generation, @JsonKey(unknownEnumValue: TailscaleMigrateOutcome.unknown) this.outcome = TailscaleMigrateOutcome.unknown, required this.migration, required this.node, @JsonKey(name: 'reapply-required') this.reapplyRequired = false, @JsonKey(name: 'target-untouched') this.targetUntouched = false, @JsonKey(name: 'archive-intact') this.archiveIntact = false, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.stage, this.error});
  factory _TailscaleMigrateResult.fromJson(Map<String, dynamic> json) => _$TailscaleMigrateResultFromJson(json);

@override final  int generation;
@override@JsonKey(unknownEnumValue: TailscaleMigrateOutcome.unknown) final  TailscaleMigrateOutcome outcome;
@override final  TailscaleLegacyMigration migration;
@override final  TailscaleNode node;
@override@JsonKey(name: 'reapply-required') final  bool reapplyRequired;
@override@JsonKey(name: 'target-untouched') final  bool targetUntouched;
@override@JsonKey(name: 'archive-intact') final  bool archiveIntact;
@override@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  TailscaleMigrateStage? stage;
@override final  TailscaleError? error;

/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleMigrateResultCopyWith<_TailscaleMigrateResult> get copyWith => __$TailscaleMigrateResultCopyWithImpl<_TailscaleMigrateResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleMigrateResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleMigrateResult&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.migration, migration) || other.migration == migration)&&(identical(other.node, node) || other.node == node)&&(identical(other.reapplyRequired, reapplyRequired) || other.reapplyRequired == reapplyRequired)&&(identical(other.targetUntouched, targetUntouched) || other.targetUntouched == targetUntouched)&&(identical(other.archiveIntact, archiveIntact) || other.archiveIntact == archiveIntact)&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,generation,outcome,migration,node,reapplyRequired,targetUntouched,archiveIntact,stage,error);
}

@override
String toString() {
    return 'TailscaleMigrateResult(generation: $generation, outcome: $outcome, migration: $migration, node: $node, reapplyRequired: $reapplyRequired, targetUntouched: $targetUntouched, archiveIntact: $archiveIntact, stage: $stage, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TailscaleMigrateResultCopyWith<$Res> implements $TailscaleMigrateResultCopyWith<$Res> {
  factory _$TailscaleMigrateResultCopyWith(_TailscaleMigrateResult value, $Res Function(_TailscaleMigrateResult) _then) = __$TailscaleMigrateResultCopyWithImpl;
@override @useResult
$Res call({
 int generation,@JsonKey(unknownEnumValue: TailscaleMigrateOutcome.unknown) TailscaleMigrateOutcome outcome, TailscaleLegacyMigration migration, TailscaleNode node,@JsonKey(name: 'reapply-required') bool reapplyRequired,@JsonKey(name: 'target-untouched') bool targetUntouched,@JsonKey(name: 'archive-intact') bool archiveIntact,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) TailscaleMigrateStage? stage, TailscaleError? error
});


@override $TailscaleLegacyMigrationCopyWith<$Res> get migration;@override $TailscaleNodeCopyWith<$Res> get node;@override $TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class __$TailscaleMigrateResultCopyWithImpl<$Res>
    implements _$TailscaleMigrateResultCopyWith<$Res> {
  __$TailscaleMigrateResultCopyWithImpl(this._self, this._then);

  final _TailscaleMigrateResult _self;
  final $Res Function(_TailscaleMigrateResult) _then;

/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generation = null,Object? outcome = null,Object? migration = null,Object? node = null,Object? reapplyRequired = null,Object? targetUntouched = null,Object? archiveIntact = null,Object? stage = freezed,Object? error = freezed,}) {
  return _then(_TailscaleMigrateResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as TailscaleMigrateOutcome,migration: null == migration ? _self.migration : migration // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyMigration,node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as TailscaleNode,reapplyRequired: null == reapplyRequired ? _self.reapplyRequired : reapplyRequired // ignore: cast_nullable_to_non_nullable
as bool,targetUntouched: null == targetUntouched ? _self.targetUntouched : targetUntouched // ignore: cast_nullable_to_non_nullable
as bool,archiveIntact: null == archiveIntact ? _self.archiveIntact : archiveIntact // ignore: cast_nullable_to_non_nullable
as bool,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as TailscaleMigrateStage?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}

/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleLegacyMigrationCopyWith<$Res> get migration {
  
  return $TailscaleLegacyMigrationCopyWith<$Res>(_self.migration, (value) {
    return _then(_self.copyWith(migration: value));
  });
}/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleNodeCopyWith<$Res> get node {
  
  return $TailscaleNodeCopyWith<$Res>(_self.node, (value) {
    return _then(_self.copyWith(node: value));
  });
}/// Create a copy of TailscaleMigrateResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$TailscaleUser {

 String get id;@JsonKey(name: 'login-name') String get loginName;@JsonKey(name: 'display-name') String get displayName;@JsonKey(name: 'profile-pic-url') String get profilePicUrl;
/// Create a copy of TailscaleUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleUserCopyWith<TailscaleUser> get copyWith => _$TailscaleUserCopyWithImpl<TailscaleUser>(this as TailscaleUser, _$identity);

  /// Serializes this TailscaleUser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleUser;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleUser&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.loginName, _this.loginName) || other.loginName == _this.loginName)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.profilePicUrl, _this.profilePicUrl) || other.profilePicUrl == _this.profilePicUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleUser;
  return Object.hash(runtimeType,_this.id,_this.loginName,_this.displayName,_this.profilePicUrl);
}

@override
String toString() {
  final _this = this as TailscaleUser;
  return 'TailscaleUser(id: ${_this.id}, loginName: ${_this.loginName}, displayName: ${_this.displayName}, profilePicUrl: ${_this.profilePicUrl})';
}


}

/// @nodoc
abstract mixin class $TailscaleUserCopyWith<$Res>  {
  factory $TailscaleUserCopyWith(TailscaleUser value, $Res Function(TailscaleUser) _then) = _$TailscaleUserCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'login-name') String loginName,@JsonKey(name: 'display-name') String displayName,@JsonKey(name: 'profile-pic-url') String profilePicUrl
});




}
/// @nodoc
class _$TailscaleUserCopyWithImpl<$Res>
    implements $TailscaleUserCopyWith<$Res> {
  _$TailscaleUserCopyWithImpl(this._self, this._then);

  final TailscaleUser _self;
  final $Res Function(TailscaleUser) _then;

/// Create a copy of TailscaleUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? loginName = null,Object? displayName = null,Object? profilePicUrl = null,}) {
  return _then(TailscaleUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,profilePicUrl: null == profilePicUrl ? _self.profilePicUrl : profilePicUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleUser].
extension TailscaleUserPatterns on TailscaleUser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleUser() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleUser value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleUser():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleUser value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleUser() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'login-name')  String loginName, @JsonKey(name: 'display-name')  String displayName, @JsonKey(name: 'profile-pic-url')  String profilePicUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleUser() when $default != null:
return $default(_that.id,_that.loginName,_that.displayName,_that.profilePicUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'login-name')  String loginName, @JsonKey(name: 'display-name')  String displayName, @JsonKey(name: 'profile-pic-url')  String profilePicUrl)  $default,) {final _that = this;
switch (_that) {
case _TailscaleUser():
return $default(_that.id,_that.loginName,_that.displayName,_that.profilePicUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'login-name')  String loginName, @JsonKey(name: 'display-name')  String displayName, @JsonKey(name: 'profile-pic-url')  String profilePicUrl)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleUser() when $default != null:
return $default(_that.id,_that.loginName,_that.displayName,_that.profilePicUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleUser implements TailscaleUser {
  const _TailscaleUser({required this.id, @JsonKey(name: 'login-name') this.loginName = '', @JsonKey(name: 'display-name') this.displayName = '', @JsonKey(name: 'profile-pic-url') this.profilePicUrl = ''});
  factory _TailscaleUser.fromJson(Map<String, dynamic> json) => _$TailscaleUserFromJson(json);

@override final  String id;
@override@JsonKey(name: 'login-name') final  String loginName;
@override@JsonKey(name: 'display-name') final  String displayName;
@override@JsonKey(name: 'profile-pic-url') final  String profilePicUrl;

/// Create a copy of TailscaleUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleUserCopyWith<_TailscaleUser> get copyWith => __$TailscaleUserCopyWithImpl<_TailscaleUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleUserToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleUser&&(identical(other.id, id) || other.id == id)&&(identical(other.loginName, loginName) || other.loginName == loginName)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.profilePicUrl, profilePicUrl) || other.profilePicUrl == profilePicUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,loginName,displayName,profilePicUrl);
}

@override
String toString() {
    return 'TailscaleUser(id: $id, loginName: $loginName, displayName: $displayName, profilePicUrl: $profilePicUrl)';
}


}

/// @nodoc
abstract mixin class _$TailscaleUserCopyWith<$Res> implements $TailscaleUserCopyWith<$Res> {
  factory _$TailscaleUserCopyWith(_TailscaleUser value, $Res Function(_TailscaleUser) _then) = __$TailscaleUserCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'login-name') String loginName,@JsonKey(name: 'display-name') String displayName,@JsonKey(name: 'profile-pic-url') String profilePicUrl
});




}
/// @nodoc
class __$TailscaleUserCopyWithImpl<$Res>
    implements _$TailscaleUserCopyWith<$Res> {
  __$TailscaleUserCopyWithImpl(this._self, this._then);

  final _TailscaleUser _self;
  final $Res Function(_TailscaleUser) _then;

/// Create a copy of TailscaleUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? loginName = null,Object? displayName = null,Object? profilePicUrl = null,}) {
  return _then(_TailscaleUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,profilePicUrl: null == profilePicUrl ? _self.profilePicUrl : profilePicUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TailscalePeer {

 String get id;@JsonKey(name: 'host-name') String get hostName;@JsonKey(name: 'dns-name') String get dnsName; String get os;@JsonKey(name: 'user-id') String get userId;@JsonKey(name: 'alt-sharer-user-id') String? get altSharerUserId; List<String> get addresses; List<String> get tags; bool get online;@JsonKey(name: 'exit-node') bool get exitNode;@JsonKey(name: 'exit-node-option') bool get exitNodeOption;@JsonKey(name: 'sharee-node') bool get shareeNode; bool get expired;@JsonKey(name: 'key-expiry') DateTime? get keyExpiry;
/// Create a copy of TailscalePeer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscalePeerCopyWith<TailscalePeer> get copyWith => _$TailscalePeerCopyWithImpl<TailscalePeer>(this as TailscalePeer, _$identity);

  /// Serializes this TailscalePeer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscalePeer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscalePeer&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.hostName, _this.hostName) || other.hostName == _this.hostName)&&(identical(other.dnsName, _this.dnsName) || other.dnsName == _this.dnsName)&&(identical(other.os, _this.os) || other.os == _this.os)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.altSharerUserId, _this.altSharerUserId) || other.altSharerUserId == _this.altSharerUserId)&&const DeepCollectionEquality().equals(other.addresses, _this.addresses)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.online, _this.online) || other.online == _this.online)&&(identical(other.exitNode, _this.exitNode) || other.exitNode == _this.exitNode)&&(identical(other.exitNodeOption, _this.exitNodeOption) || other.exitNodeOption == _this.exitNodeOption)&&(identical(other.shareeNode, _this.shareeNode) || other.shareeNode == _this.shareeNode)&&(identical(other.expired, _this.expired) || other.expired == _this.expired)&&(identical(other.keyExpiry, _this.keyExpiry) || other.keyExpiry == _this.keyExpiry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscalePeer;
  return Object.hash(runtimeType,_this.id,_this.hostName,_this.dnsName,_this.os,_this.userId,_this.altSharerUserId,const DeepCollectionEquality().hash(_this.addresses),const DeepCollectionEquality().hash(_this.tags),_this.online,_this.exitNode,_this.exitNodeOption,_this.shareeNode,_this.expired,_this.keyExpiry);
}

@override
String toString() {
  final _this = this as TailscalePeer;
  return 'TailscalePeer(id: ${_this.id}, hostName: ${_this.hostName}, dnsName: ${_this.dnsName}, os: ${_this.os}, userId: ${_this.userId}, altSharerUserId: ${_this.altSharerUserId}, addresses: ${_this.addresses}, tags: ${_this.tags}, online: ${_this.online}, exitNode: ${_this.exitNode}, exitNodeOption: ${_this.exitNodeOption}, shareeNode: ${_this.shareeNode}, expired: ${_this.expired}, keyExpiry: ${_this.keyExpiry})';
}


}

/// @nodoc
abstract mixin class $TailscalePeerCopyWith<$Res>  {
  factory $TailscalePeerCopyWith(TailscalePeer value, $Res Function(TailscalePeer) _then) = _$TailscalePeerCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'host-name') String hostName,@JsonKey(name: 'dns-name') String dnsName, String os,@JsonKey(name: 'user-id') String userId,@JsonKey(name: 'alt-sharer-user-id') String? altSharerUserId, List<String> addresses, List<String> tags, bool online,@JsonKey(name: 'exit-node') bool exitNode,@JsonKey(name: 'exit-node-option') bool exitNodeOption,@JsonKey(name: 'sharee-node') bool shareeNode, bool expired,@JsonKey(name: 'key-expiry') DateTime? keyExpiry
});




}
/// @nodoc
class _$TailscalePeerCopyWithImpl<$Res>
    implements $TailscalePeerCopyWith<$Res> {
  _$TailscalePeerCopyWithImpl(this._self, this._then);

  final TailscalePeer _self;
  final $Res Function(TailscalePeer) _then;

/// Create a copy of TailscalePeer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? hostName = null,Object? dnsName = null,Object? os = null,Object? userId = null,Object? altSharerUserId = freezed,Object? addresses = null,Object? tags = null,Object? online = null,Object? exitNode = null,Object? exitNodeOption = null,Object? shareeNode = null,Object? expired = null,Object? keyExpiry = freezed,}) {
  return _then(TailscalePeer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hostName: null == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String,dnsName: null == dnsName ? _self.dnsName : dnsName // ignore: cast_nullable_to_non_nullable
as String,os: null == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,altSharerUserId: freezed == altSharerUserId ? _self.altSharerUserId : altSharerUserId // ignore: cast_nullable_to_non_nullable
as String?,addresses: null == addresses ? _self.addresses : addresses // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,exitNode: null == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as bool,exitNodeOption: null == exitNodeOption ? _self.exitNodeOption : exitNodeOption // ignore: cast_nullable_to_non_nullable
as bool,shareeNode: null == shareeNode ? _self.shareeNode : shareeNode // ignore: cast_nullable_to_non_nullable
as bool,expired: null == expired ? _self.expired : expired // ignore: cast_nullable_to_non_nullable
as bool,keyExpiry: freezed == keyExpiry ? _self.keyExpiry : keyExpiry // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscalePeer].
extension TailscalePeerPatterns on TailscalePeer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscalePeer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscalePeer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscalePeer value)  $default,){
final _that = this;
switch (_that) {
case _TailscalePeer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscalePeer value)?  $default,){
final _that = this;
switch (_that) {
case _TailscalePeer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'host-name')  String hostName, @JsonKey(name: 'dns-name')  String dnsName,  String os, @JsonKey(name: 'user-id')  String userId, @JsonKey(name: 'alt-sharer-user-id')  String? altSharerUserId,  List<String> addresses,  List<String> tags,  bool online, @JsonKey(name: 'exit-node')  bool exitNode, @JsonKey(name: 'exit-node-option')  bool exitNodeOption, @JsonKey(name: 'sharee-node')  bool shareeNode,  bool expired, @JsonKey(name: 'key-expiry')  DateTime? keyExpiry)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscalePeer() when $default != null:
return $default(_that.id,_that.hostName,_that.dnsName,_that.os,_that.userId,_that.altSharerUserId,_that.addresses,_that.tags,_that.online,_that.exitNode,_that.exitNodeOption,_that.shareeNode,_that.expired,_that.keyExpiry);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'host-name')  String hostName, @JsonKey(name: 'dns-name')  String dnsName,  String os, @JsonKey(name: 'user-id')  String userId, @JsonKey(name: 'alt-sharer-user-id')  String? altSharerUserId,  List<String> addresses,  List<String> tags,  bool online, @JsonKey(name: 'exit-node')  bool exitNode, @JsonKey(name: 'exit-node-option')  bool exitNodeOption, @JsonKey(name: 'sharee-node')  bool shareeNode,  bool expired, @JsonKey(name: 'key-expiry')  DateTime? keyExpiry)  $default,) {final _that = this;
switch (_that) {
case _TailscalePeer():
return $default(_that.id,_that.hostName,_that.dnsName,_that.os,_that.userId,_that.altSharerUserId,_that.addresses,_that.tags,_that.online,_that.exitNode,_that.exitNodeOption,_that.shareeNode,_that.expired,_that.keyExpiry);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'host-name')  String hostName, @JsonKey(name: 'dns-name')  String dnsName,  String os, @JsonKey(name: 'user-id')  String userId, @JsonKey(name: 'alt-sharer-user-id')  String? altSharerUserId,  List<String> addresses,  List<String> tags,  bool online, @JsonKey(name: 'exit-node')  bool exitNode, @JsonKey(name: 'exit-node-option')  bool exitNodeOption, @JsonKey(name: 'sharee-node')  bool shareeNode,  bool expired, @JsonKey(name: 'key-expiry')  DateTime? keyExpiry)?  $default,) {final _that = this;
switch (_that) {
case _TailscalePeer() when $default != null:
return $default(_that.id,_that.hostName,_that.dnsName,_that.os,_that.userId,_that.altSharerUserId,_that.addresses,_that.tags,_that.online,_that.exitNode,_that.exitNodeOption,_that.shareeNode,_that.expired,_that.keyExpiry);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscalePeer implements TailscalePeer {
  const _TailscalePeer({required this.id, @JsonKey(name: 'host-name') this.hostName = '', @JsonKey(name: 'dns-name') this.dnsName = '', this.os = '', @JsonKey(name: 'user-id') this.userId = '', @JsonKey(name: 'alt-sharer-user-id') this.altSharerUserId,  List<String> addresses = const [],  List<String> tags = const [], this.online = false, @JsonKey(name: 'exit-node') this.exitNode = false, @JsonKey(name: 'exit-node-option') this.exitNodeOption = false, @JsonKey(name: 'sharee-node') this.shareeNode = false, this.expired = false, @JsonKey(name: 'key-expiry') this.keyExpiry}): _addresses = addresses,_tags = tags;
  factory _TailscalePeer.fromJson(Map<String, dynamic> json) => _$TailscalePeerFromJson(json);

@override final  String id;
@override@JsonKey(name: 'host-name') final  String hostName;
@override@JsonKey(name: 'dns-name') final  String dnsName;
@override@JsonKey() final  String os;
@override@JsonKey(name: 'user-id') final  String userId;
@override@JsonKey(name: 'alt-sharer-user-id') final  String? altSharerUserId;
 final  List<String> _addresses;
@override@JsonKey() List<String> get addresses {
  if (_addresses is EqualUnmodifiableListView) return _addresses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_addresses);
}

 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override@JsonKey() final  bool online;
@override@JsonKey(name: 'exit-node') final  bool exitNode;
@override@JsonKey(name: 'exit-node-option') final  bool exitNodeOption;
@override@JsonKey(name: 'sharee-node') final  bool shareeNode;
@override@JsonKey() final  bool expired;
@override@JsonKey(name: 'key-expiry') final  DateTime? keyExpiry;

/// Create a copy of TailscalePeer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscalePeerCopyWith<_TailscalePeer> get copyWith => __$TailscalePeerCopyWithImpl<_TailscalePeer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscalePeerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscalePeer&&(identical(other.id, id) || other.id == id)&&(identical(other.hostName, hostName) || other.hostName == hostName)&&(identical(other.dnsName, dnsName) || other.dnsName == dnsName)&&(identical(other.os, os) || other.os == os)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.altSharerUserId, altSharerUserId) || other.altSharerUserId == altSharerUserId)&&const DeepCollectionEquality().equals(other.addresses, _addresses)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.online, online) || other.online == online)&&(identical(other.exitNode, exitNode) || other.exitNode == exitNode)&&(identical(other.exitNodeOption, exitNodeOption) || other.exitNodeOption == exitNodeOption)&&(identical(other.shareeNode, shareeNode) || other.shareeNode == shareeNode)&&(identical(other.expired, expired) || other.expired == expired)&&(identical(other.keyExpiry, keyExpiry) || other.keyExpiry == keyExpiry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,hostName,dnsName,os,userId,altSharerUserId,const DeepCollectionEquality().hash(_addresses),const DeepCollectionEquality().hash(_tags),online,exitNode,exitNodeOption,shareeNode,expired,keyExpiry);
}

@override
String toString() {
    return 'TailscalePeer(id: $id, hostName: $hostName, dnsName: $dnsName, os: $os, userId: $userId, altSharerUserId: $altSharerUserId, addresses: $addresses, tags: $tags, online: $online, exitNode: $exitNode, exitNodeOption: $exitNodeOption, shareeNode: $shareeNode, expired: $expired, keyExpiry: $keyExpiry)';
}


}

/// @nodoc
abstract mixin class _$TailscalePeerCopyWith<$Res> implements $TailscalePeerCopyWith<$Res> {
  factory _$TailscalePeerCopyWith(_TailscalePeer value, $Res Function(_TailscalePeer) _then) = __$TailscalePeerCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'host-name') String hostName,@JsonKey(name: 'dns-name') String dnsName, String os,@JsonKey(name: 'user-id') String userId,@JsonKey(name: 'alt-sharer-user-id') String? altSharerUserId, List<String> addresses, List<String> tags, bool online,@JsonKey(name: 'exit-node') bool exitNode,@JsonKey(name: 'exit-node-option') bool exitNodeOption,@JsonKey(name: 'sharee-node') bool shareeNode, bool expired,@JsonKey(name: 'key-expiry') DateTime? keyExpiry
});




}
/// @nodoc
class __$TailscalePeerCopyWithImpl<$Res>
    implements _$TailscalePeerCopyWith<$Res> {
  __$TailscalePeerCopyWithImpl(this._self, this._then);

  final _TailscalePeer _self;
  final $Res Function(_TailscalePeer) _then;

/// Create a copy of TailscalePeer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? hostName = null,Object? dnsName = null,Object? os = null,Object? userId = null,Object? altSharerUserId = freezed,Object? addresses = null,Object? tags = null,Object? online = null,Object? exitNode = null,Object? exitNodeOption = null,Object? shareeNode = null,Object? expired = null,Object? keyExpiry = freezed,}) {
  return _then(_TailscalePeer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hostName: null == hostName ? _self.hostName : hostName // ignore: cast_nullable_to_non_nullable
as String,dnsName: null == dnsName ? _self.dnsName : dnsName // ignore: cast_nullable_to_non_nullable
as String,os: null == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,altSharerUserId: freezed == altSharerUserId ? _self.altSharerUserId : altSharerUserId // ignore: cast_nullable_to_non_nullable
as String?,addresses: null == addresses ? _self._addresses : addresses // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,exitNode: null == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as bool,exitNodeOption: null == exitNodeOption ? _self.exitNodeOption : exitNodeOption // ignore: cast_nullable_to_non_nullable
as bool,shareeNode: null == shareeNode ? _self.shareeNode : shareeNode // ignore: cast_nullable_to_non_nullable
as bool,expired: null == expired ? _self.expired : expired // ignore: cast_nullable_to_non_nullable
as bool,keyExpiry: freezed == keyExpiry ? _self.keyExpiry : keyExpiry // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$TailscaleTailnet {

 String get name;@JsonKey(name: 'magic-dns-suffix') String get magicDnsSuffix;@JsonKey(name: 'magic-dns-enabled') bool get magicDnsEnabled;
/// Create a copy of TailscaleTailnet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleTailnetCopyWith<TailscaleTailnet> get copyWith => _$TailscaleTailnetCopyWithImpl<TailscaleTailnet>(this as TailscaleTailnet, _$identity);

  /// Serializes this TailscaleTailnet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleTailnet;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleTailnet&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.magicDnsSuffix, _this.magicDnsSuffix) || other.magicDnsSuffix == _this.magicDnsSuffix)&&(identical(other.magicDnsEnabled, _this.magicDnsEnabled) || other.magicDnsEnabled == _this.magicDnsEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleTailnet;
  return Object.hash(runtimeType,_this.name,_this.magicDnsSuffix,_this.magicDnsEnabled);
}

@override
String toString() {
  final _this = this as TailscaleTailnet;
  return 'TailscaleTailnet(name: ${_this.name}, magicDnsSuffix: ${_this.magicDnsSuffix}, magicDnsEnabled: ${_this.magicDnsEnabled})';
}


}

/// @nodoc
abstract mixin class $TailscaleTailnetCopyWith<$Res>  {
  factory $TailscaleTailnetCopyWith(TailscaleTailnet value, $Res Function(TailscaleTailnet) _then) = _$TailscaleTailnetCopyWithImpl;
@useResult
$Res call({
 String name,@JsonKey(name: 'magic-dns-suffix') String magicDnsSuffix,@JsonKey(name: 'magic-dns-enabled') bool magicDnsEnabled
});




}
/// @nodoc
class _$TailscaleTailnetCopyWithImpl<$Res>
    implements $TailscaleTailnetCopyWith<$Res> {
  _$TailscaleTailnetCopyWithImpl(this._self, this._then);

  final TailscaleTailnet _self;
  final $Res Function(TailscaleTailnet) _then;

/// Create a copy of TailscaleTailnet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? magicDnsSuffix = null,Object? magicDnsEnabled = null,}) {
  return _then(TailscaleTailnet(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,magicDnsSuffix: null == magicDnsSuffix ? _self.magicDnsSuffix : magicDnsSuffix // ignore: cast_nullable_to_non_nullable
as String,magicDnsEnabled: null == magicDnsEnabled ? _self.magicDnsEnabled : magicDnsEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleTailnet].
extension TailscaleTailnetPatterns on TailscaleTailnet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleTailnet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleTailnet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleTailnet value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleTailnet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleTailnet value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleTailnet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name, @JsonKey(name: 'magic-dns-suffix')  String magicDnsSuffix, @JsonKey(name: 'magic-dns-enabled')  bool magicDnsEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleTailnet() when $default != null:
return $default(_that.name,_that.magicDnsSuffix,_that.magicDnsEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name, @JsonKey(name: 'magic-dns-suffix')  String magicDnsSuffix, @JsonKey(name: 'magic-dns-enabled')  bool magicDnsEnabled)  $default,) {final _that = this;
switch (_that) {
case _TailscaleTailnet():
return $default(_that.name,_that.magicDnsSuffix,_that.magicDnsEnabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name, @JsonKey(name: 'magic-dns-suffix')  String magicDnsSuffix, @JsonKey(name: 'magic-dns-enabled')  bool magicDnsEnabled)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleTailnet() when $default != null:
return $default(_that.name,_that.magicDnsSuffix,_that.magicDnsEnabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleTailnet implements TailscaleTailnet {
  const _TailscaleTailnet({this.name = '', @JsonKey(name: 'magic-dns-suffix') this.magicDnsSuffix = '', @JsonKey(name: 'magic-dns-enabled') this.magicDnsEnabled = false});
  factory _TailscaleTailnet.fromJson(Map<String, dynamic> json) => _$TailscaleTailnetFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey(name: 'magic-dns-suffix') final  String magicDnsSuffix;
@override@JsonKey(name: 'magic-dns-enabled') final  bool magicDnsEnabled;

/// Create a copy of TailscaleTailnet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleTailnetCopyWith<_TailscaleTailnet> get copyWith => __$TailscaleTailnetCopyWithImpl<_TailscaleTailnet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleTailnetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleTailnet&&(identical(other.name, name) || other.name == name)&&(identical(other.magicDnsSuffix, magicDnsSuffix) || other.magicDnsSuffix == magicDnsSuffix)&&(identical(other.magicDnsEnabled, magicDnsEnabled) || other.magicDnsEnabled == magicDnsEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,magicDnsSuffix,magicDnsEnabled);
}

@override
String toString() {
    return 'TailscaleTailnet(name: $name, magicDnsSuffix: $magicDnsSuffix, magicDnsEnabled: $magicDnsEnabled)';
}


}

/// @nodoc
abstract mixin class _$TailscaleTailnetCopyWith<$Res> implements $TailscaleTailnetCopyWith<$Res> {
  factory _$TailscaleTailnetCopyWith(_TailscaleTailnet value, $Res Function(_TailscaleTailnet) _then) = __$TailscaleTailnetCopyWithImpl;
@override @useResult
$Res call({
 String name,@JsonKey(name: 'magic-dns-suffix') String magicDnsSuffix,@JsonKey(name: 'magic-dns-enabled') bool magicDnsEnabled
});




}
/// @nodoc
class __$TailscaleTailnetCopyWithImpl<$Res>
    implements _$TailscaleTailnetCopyWith<$Res> {
  __$TailscaleTailnetCopyWithImpl(this._self, this._then);

  final _TailscaleTailnet _self;
  final $Res Function(_TailscaleTailnet) _then;

/// Create a copy of TailscaleTailnet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? magicDnsSuffix = null,Object? magicDnsEnabled = null,}) {
  return _then(_TailscaleTailnet(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,magicDnsSuffix: null == magicDnsSuffix ? _self.magicDnsSuffix : magicDnsSuffix // ignore: cast_nullable_to_non_nullable
as String,magicDnsEnabled: null == magicDnsEnabled ? _self.magicDnsEnabled : magicDnsEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TailscalePrefs {

@JsonKey(name: 'exit-node-id') String get exitNodeId;@JsonKey(name: 'exit-node-ip') String get exitNodeIp;@JsonKey(name: 'auto-exit-node') String get autoExitNode;@JsonKey(name: 'accept-routes') bool get acceptRoutes;
/// Create a copy of TailscalePrefs
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscalePrefsCopyWith<TailscalePrefs> get copyWith => _$TailscalePrefsCopyWithImpl<TailscalePrefs>(this as TailscalePrefs, _$identity);

  /// Serializes this TailscalePrefs to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscalePrefs;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscalePrefs&&(identical(other.exitNodeId, _this.exitNodeId) || other.exitNodeId == _this.exitNodeId)&&(identical(other.exitNodeIp, _this.exitNodeIp) || other.exitNodeIp == _this.exitNodeIp)&&(identical(other.autoExitNode, _this.autoExitNode) || other.autoExitNode == _this.autoExitNode)&&(identical(other.acceptRoutes, _this.acceptRoutes) || other.acceptRoutes == _this.acceptRoutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscalePrefs;
  return Object.hash(runtimeType,_this.exitNodeId,_this.exitNodeIp,_this.autoExitNode,_this.acceptRoutes);
}

@override
String toString() {
  final _this = this as TailscalePrefs;
  return 'TailscalePrefs(exitNodeId: ${_this.exitNodeId}, exitNodeIp: ${_this.exitNodeIp}, autoExitNode: ${_this.autoExitNode}, acceptRoutes: ${_this.acceptRoutes})';
}


}

/// @nodoc
abstract mixin class $TailscalePrefsCopyWith<$Res>  {
  factory $TailscalePrefsCopyWith(TailscalePrefs value, $Res Function(TailscalePrefs) _then) = _$TailscalePrefsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'exit-node-id') String exitNodeId,@JsonKey(name: 'exit-node-ip') String exitNodeIp,@JsonKey(name: 'auto-exit-node') String autoExitNode,@JsonKey(name: 'accept-routes') bool acceptRoutes
});




}
/// @nodoc
class _$TailscalePrefsCopyWithImpl<$Res>
    implements $TailscalePrefsCopyWith<$Res> {
  _$TailscalePrefsCopyWithImpl(this._self, this._then);

  final TailscalePrefs _self;
  final $Res Function(TailscalePrefs) _then;

/// Create a copy of TailscalePrefs
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? exitNodeId = null,Object? exitNodeIp = null,Object? autoExitNode = null,Object? acceptRoutes = null,}) {
  return _then(TailscalePrefs(
exitNodeId: null == exitNodeId ? _self.exitNodeId : exitNodeId // ignore: cast_nullable_to_non_nullable
as String,exitNodeIp: null == exitNodeIp ? _self.exitNodeIp : exitNodeIp // ignore: cast_nullable_to_non_nullable
as String,autoExitNode: null == autoExitNode ? _self.autoExitNode : autoExitNode // ignore: cast_nullable_to_non_nullable
as String,acceptRoutes: null == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscalePrefs].
extension TailscalePrefsPatterns on TailscalePrefs {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscalePrefs value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscalePrefs() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscalePrefs value)  $default,){
final _that = this;
switch (_that) {
case _TailscalePrefs():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscalePrefs value)?  $default,){
final _that = this;
switch (_that) {
case _TailscalePrefs() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'exit-node-id')  String exitNodeId, @JsonKey(name: 'exit-node-ip')  String exitNodeIp, @JsonKey(name: 'auto-exit-node')  String autoExitNode, @JsonKey(name: 'accept-routes')  bool acceptRoutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscalePrefs() when $default != null:
return $default(_that.exitNodeId,_that.exitNodeIp,_that.autoExitNode,_that.acceptRoutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'exit-node-id')  String exitNodeId, @JsonKey(name: 'exit-node-ip')  String exitNodeIp, @JsonKey(name: 'auto-exit-node')  String autoExitNode, @JsonKey(name: 'accept-routes')  bool acceptRoutes)  $default,) {final _that = this;
switch (_that) {
case _TailscalePrefs():
return $default(_that.exitNodeId,_that.exitNodeIp,_that.autoExitNode,_that.acceptRoutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'exit-node-id')  String exitNodeId, @JsonKey(name: 'exit-node-ip')  String exitNodeIp, @JsonKey(name: 'auto-exit-node')  String autoExitNode, @JsonKey(name: 'accept-routes')  bool acceptRoutes)?  $default,) {final _that = this;
switch (_that) {
case _TailscalePrefs() when $default != null:
return $default(_that.exitNodeId,_that.exitNodeIp,_that.autoExitNode,_that.acceptRoutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscalePrefs implements TailscalePrefs {
  const _TailscalePrefs({@JsonKey(name: 'exit-node-id') this.exitNodeId = '', @JsonKey(name: 'exit-node-ip') this.exitNodeIp = '', @JsonKey(name: 'auto-exit-node') this.autoExitNode = '', @JsonKey(name: 'accept-routes') this.acceptRoutes = false});
  factory _TailscalePrefs.fromJson(Map<String, dynamic> json) => _$TailscalePrefsFromJson(json);

@override@JsonKey(name: 'exit-node-id') final  String exitNodeId;
@override@JsonKey(name: 'exit-node-ip') final  String exitNodeIp;
@override@JsonKey(name: 'auto-exit-node') final  String autoExitNode;
@override@JsonKey(name: 'accept-routes') final  bool acceptRoutes;

/// Create a copy of TailscalePrefs
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscalePrefsCopyWith<_TailscalePrefs> get copyWith => __$TailscalePrefsCopyWithImpl<_TailscalePrefs>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscalePrefsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscalePrefs&&(identical(other.exitNodeId, exitNodeId) || other.exitNodeId == exitNodeId)&&(identical(other.exitNodeIp, exitNodeIp) || other.exitNodeIp == exitNodeIp)&&(identical(other.autoExitNode, autoExitNode) || other.autoExitNode == autoExitNode)&&(identical(other.acceptRoutes, acceptRoutes) || other.acceptRoutes == acceptRoutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,exitNodeId,exitNodeIp,autoExitNode,acceptRoutes);
}

@override
String toString() {
    return 'TailscalePrefs(exitNodeId: $exitNodeId, exitNodeIp: $exitNodeIp, autoExitNode: $autoExitNode, acceptRoutes: $acceptRoutes)';
}


}

/// @nodoc
abstract mixin class _$TailscalePrefsCopyWith<$Res> implements $TailscalePrefsCopyWith<$Res> {
  factory _$TailscalePrefsCopyWith(_TailscalePrefs value, $Res Function(_TailscalePrefs) _then) = __$TailscalePrefsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'exit-node-id') String exitNodeId,@JsonKey(name: 'exit-node-ip') String exitNodeIp,@JsonKey(name: 'auto-exit-node') String autoExitNode,@JsonKey(name: 'accept-routes') bool acceptRoutes
});




}
/// @nodoc
class __$TailscalePrefsCopyWithImpl<$Res>
    implements _$TailscalePrefsCopyWith<$Res> {
  __$TailscalePrefsCopyWithImpl(this._self, this._then);

  final _TailscalePrefs _self;
  final $Res Function(_TailscalePrefs) _then;

/// Create a copy of TailscalePrefs
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? exitNodeId = null,Object? exitNodeIp = null,Object? autoExitNode = null,Object? acceptRoutes = null,}) {
  return _then(_TailscalePrefs(
exitNodeId: null == exitNodeId ? _self.exitNodeId : exitNodeId // ignore: cast_nullable_to_non_nullable
as String,exitNodeIp: null == exitNodeIp ? _self.exitNodeIp : exitNodeIp // ignore: cast_nullable_to_non_nullable
as String,autoExitNode: null == autoExitNode ? _self.autoExitNode : autoExitNode // ignore: cast_nullable_to_non_nullable
as String,acceptRoutes: null == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TailscaleStatus {

 TailscaleNode get node;@JsonKey(name: 'auth-url-ready') bool get authUrlReady;@JsonKey(name: 'have-node-key') bool get haveNodeKey; TailscalePeer? get self;@JsonKey(name: 'login-user') TailscaleUser? get loginUser; TailscaleTailnet? get tailnet; Map<String, TailscaleUser> get users; List<TailscalePeer> get peers; TailscalePrefs? get prefs; List<String> get health;
/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleStatusCopyWith<TailscaleStatus> get copyWith => _$TailscaleStatusCopyWithImpl<TailscaleStatus>(this as TailscaleStatus, _$identity);

  /// Serializes this TailscaleStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleStatus&&(identical(other.node, _this.node) || other.node == _this.node)&&(identical(other.authUrlReady, _this.authUrlReady) || other.authUrlReady == _this.authUrlReady)&&(identical(other.haveNodeKey, _this.haveNodeKey) || other.haveNodeKey == _this.haveNodeKey)&&(identical(other.self, _this.self) || other.self == _this.self)&&(identical(other.loginUser, _this.loginUser) || other.loginUser == _this.loginUser)&&(identical(other.tailnet, _this.tailnet) || other.tailnet == _this.tailnet)&&const DeepCollectionEquality().equals(other.users, _this.users)&&const DeepCollectionEquality().equals(other.peers, _this.peers)&&(identical(other.prefs, _this.prefs) || other.prefs == _this.prefs)&&const DeepCollectionEquality().equals(other.health, _this.health));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleStatus;
  return Object.hash(runtimeType,_this.node,_this.authUrlReady,_this.haveNodeKey,_this.self,_this.loginUser,_this.tailnet,const DeepCollectionEquality().hash(_this.users),const DeepCollectionEquality().hash(_this.peers),_this.prefs,const DeepCollectionEquality().hash(_this.health));
}

@override
String toString() {
  final _this = this as TailscaleStatus;
  return 'TailscaleStatus(node: ${_this.node}, authUrlReady: ${_this.authUrlReady}, haveNodeKey: ${_this.haveNodeKey}, self: ${_this.self}, loginUser: ${_this.loginUser}, tailnet: ${_this.tailnet}, users: ${_this.users}, peers: ${_this.peers}, prefs: ${_this.prefs}, health: ${_this.health})';
}


}

/// @nodoc
abstract mixin class $TailscaleStatusCopyWith<$Res>  {
  factory $TailscaleStatusCopyWith(TailscaleStatus value, $Res Function(TailscaleStatus) _then) = _$TailscaleStatusCopyWithImpl;
@useResult
$Res call({
 TailscaleNode node,@JsonKey(name: 'auth-url-ready') bool authUrlReady,@JsonKey(name: 'have-node-key') bool haveNodeKey, TailscalePeer? self,@JsonKey(name: 'login-user') TailscaleUser? loginUser, TailscaleTailnet? tailnet, Map<String, TailscaleUser> users, List<TailscalePeer> peers, TailscalePrefs? prefs, List<String> health
});


$TailscaleNodeCopyWith<$Res> get node;$TailscalePeerCopyWith<$Res>? get self;$TailscaleUserCopyWith<$Res>? get loginUser;$TailscaleTailnetCopyWith<$Res>? get tailnet;$TailscalePrefsCopyWith<$Res>? get prefs;

}
/// @nodoc
class _$TailscaleStatusCopyWithImpl<$Res>
    implements $TailscaleStatusCopyWith<$Res> {
  _$TailscaleStatusCopyWithImpl(this._self, this._then);

  final TailscaleStatus _self;
  final $Res Function(TailscaleStatus) _then;

/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? node = null,Object? authUrlReady = null,Object? haveNodeKey = null,Object? self = freezed,Object? loginUser = freezed,Object? tailnet = freezed,Object? users = null,Object? peers = null,Object? prefs = freezed,Object? health = null,}) {
  return _then(TailscaleStatus(
node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as TailscaleNode,authUrlReady: null == authUrlReady ? _self.authUrlReady : authUrlReady // ignore: cast_nullable_to_non_nullable
as bool,haveNodeKey: null == haveNodeKey ? _self.haveNodeKey : haveNodeKey // ignore: cast_nullable_to_non_nullable
as bool,self: freezed == self ? _self.self : self // ignore: cast_nullable_to_non_nullable
as TailscalePeer?,loginUser: freezed == loginUser ? _self.loginUser : loginUser // ignore: cast_nullable_to_non_nullable
as TailscaleUser?,tailnet: freezed == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as TailscaleTailnet?,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as Map<String, TailscaleUser>,peers: null == peers ? _self.peers : peers // ignore: cast_nullable_to_non_nullable
as List<TailscalePeer>,prefs: freezed == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as TailscalePrefs?,health: null == health ? _self.health : health // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleNodeCopyWith<$Res> get node {
  
  return $TailscaleNodeCopyWith<$Res>(_self.node, (value) {
    return _then(_self.copyWith(node: value));
  });
}/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscalePeerCopyWith<$Res>? get self {
    if (_self.self == null) {
    return null;
  }

  return $TailscalePeerCopyWith<$Res>(_self.self!, (value) {
    return _then(_self.copyWith(self: value));
  });
}/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleUserCopyWith<$Res>? get loginUser {
    if (_self.loginUser == null) {
    return null;
  }

  return $TailscaleUserCopyWith<$Res>(_self.loginUser!, (value) {
    return _then(_self.copyWith(loginUser: value));
  });
}/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleTailnetCopyWith<$Res>? get tailnet {
    if (_self.tailnet == null) {
    return null;
  }

  return $TailscaleTailnetCopyWith<$Res>(_self.tailnet!, (value) {
    return _then(_self.copyWith(tailnet: value));
  });
}/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscalePrefsCopyWith<$Res>? get prefs {
    if (_self.prefs == null) {
    return null;
  }

  return $TailscalePrefsCopyWith<$Res>(_self.prefs!, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleStatus].
extension TailscaleStatusPatterns on TailscaleStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleStatus value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleStatus value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TailscaleNode node, @JsonKey(name: 'auth-url-ready')  bool authUrlReady, @JsonKey(name: 'have-node-key')  bool haveNodeKey,  TailscalePeer? self, @JsonKey(name: 'login-user')  TailscaleUser? loginUser,  TailscaleTailnet? tailnet,  Map<String, TailscaleUser> users,  List<TailscalePeer> peers,  TailscalePrefs? prefs,  List<String> health)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleStatus() when $default != null:
return $default(_that.node,_that.authUrlReady,_that.haveNodeKey,_that.self,_that.loginUser,_that.tailnet,_that.users,_that.peers,_that.prefs,_that.health);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TailscaleNode node, @JsonKey(name: 'auth-url-ready')  bool authUrlReady, @JsonKey(name: 'have-node-key')  bool haveNodeKey,  TailscalePeer? self, @JsonKey(name: 'login-user')  TailscaleUser? loginUser,  TailscaleTailnet? tailnet,  Map<String, TailscaleUser> users,  List<TailscalePeer> peers,  TailscalePrefs? prefs,  List<String> health)  $default,) {final _that = this;
switch (_that) {
case _TailscaleStatus():
return $default(_that.node,_that.authUrlReady,_that.haveNodeKey,_that.self,_that.loginUser,_that.tailnet,_that.users,_that.peers,_that.prefs,_that.health);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TailscaleNode node, @JsonKey(name: 'auth-url-ready')  bool authUrlReady, @JsonKey(name: 'have-node-key')  bool haveNodeKey,  TailscalePeer? self, @JsonKey(name: 'login-user')  TailscaleUser? loginUser,  TailscaleTailnet? tailnet,  Map<String, TailscaleUser> users,  List<TailscalePeer> peers,  TailscalePrefs? prefs,  List<String> health)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleStatus() when $default != null:
return $default(_that.node,_that.authUrlReady,_that.haveNodeKey,_that.self,_that.loginUser,_that.tailnet,_that.users,_that.peers,_that.prefs,_that.health);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleStatus implements TailscaleStatus {
  const _TailscaleStatus({required this.node, @JsonKey(name: 'auth-url-ready') this.authUrlReady = false, @JsonKey(name: 'have-node-key') this.haveNodeKey = false, this.self, @JsonKey(name: 'login-user') this.loginUser, this.tailnet,  Map<String, TailscaleUser> users = const {},  List<TailscalePeer> peers = const [], this.prefs,  List<String> health = const []}): _users = users,_peers = peers,_health = health;
  factory _TailscaleStatus.fromJson(Map<String, dynamic> json) => _$TailscaleStatusFromJson(json);

@override final  TailscaleNode node;
@override@JsonKey(name: 'auth-url-ready') final  bool authUrlReady;
@override@JsonKey(name: 'have-node-key') final  bool haveNodeKey;
@override final  TailscalePeer? self;
@override@JsonKey(name: 'login-user') final  TailscaleUser? loginUser;
@override final  TailscaleTailnet? tailnet;
 final  Map<String, TailscaleUser> _users;
@override@JsonKey() Map<String, TailscaleUser> get users {
  if (_users is EqualUnmodifiableMapView) return _users;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_users);
}

 final  List<TailscalePeer> _peers;
@override@JsonKey() List<TailscalePeer> get peers {
  if (_peers is EqualUnmodifiableListView) return _peers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_peers);
}

@override final  TailscalePrefs? prefs;
 final  List<String> _health;
@override@JsonKey() List<String> get health {
  if (_health is EqualUnmodifiableListView) return _health;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_health);
}


/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleStatusCopyWith<_TailscaleStatus> get copyWith => __$TailscaleStatusCopyWithImpl<_TailscaleStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleStatus&&(identical(other.node, node) || other.node == node)&&(identical(other.authUrlReady, authUrlReady) || other.authUrlReady == authUrlReady)&&(identical(other.haveNodeKey, haveNodeKey) || other.haveNodeKey == haveNodeKey)&&(identical(other.self, self) || other.self == self)&&(identical(other.loginUser, loginUser) || other.loginUser == loginUser)&&(identical(other.tailnet, tailnet) || other.tailnet == tailnet)&&const DeepCollectionEquality().equals(other.users, _users)&&const DeepCollectionEquality().equals(other.peers, _peers)&&(identical(other.prefs, prefs) || other.prefs == prefs)&&const DeepCollectionEquality().equals(other.health, _health));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,node,authUrlReady,haveNodeKey,self,loginUser,tailnet,const DeepCollectionEquality().hash(_users),const DeepCollectionEquality().hash(_peers),prefs,const DeepCollectionEquality().hash(_health));
}

@override
String toString() {
    return 'TailscaleStatus(node: $node, authUrlReady: $authUrlReady, haveNodeKey: $haveNodeKey, self: $self, loginUser: $loginUser, tailnet: $tailnet, users: $users, peers: $peers, prefs: $prefs, health: $health)';
}


}

/// @nodoc
abstract mixin class _$TailscaleStatusCopyWith<$Res> implements $TailscaleStatusCopyWith<$Res> {
  factory _$TailscaleStatusCopyWith(_TailscaleStatus value, $Res Function(_TailscaleStatus) _then) = __$TailscaleStatusCopyWithImpl;
@override @useResult
$Res call({
 TailscaleNode node,@JsonKey(name: 'auth-url-ready') bool authUrlReady,@JsonKey(name: 'have-node-key') bool haveNodeKey, TailscalePeer? self,@JsonKey(name: 'login-user') TailscaleUser? loginUser, TailscaleTailnet? tailnet, Map<String, TailscaleUser> users, List<TailscalePeer> peers, TailscalePrefs? prefs, List<String> health
});


@override $TailscaleNodeCopyWith<$Res> get node;@override $TailscalePeerCopyWith<$Res>? get self;@override $TailscaleUserCopyWith<$Res>? get loginUser;@override $TailscaleTailnetCopyWith<$Res>? get tailnet;@override $TailscalePrefsCopyWith<$Res>? get prefs;

}
/// @nodoc
class __$TailscaleStatusCopyWithImpl<$Res>
    implements _$TailscaleStatusCopyWith<$Res> {
  __$TailscaleStatusCopyWithImpl(this._self, this._then);

  final _TailscaleStatus _self;
  final $Res Function(_TailscaleStatus) _then;

/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? node = null,Object? authUrlReady = null,Object? haveNodeKey = null,Object? self = freezed,Object? loginUser = freezed,Object? tailnet = freezed,Object? users = null,Object? peers = null,Object? prefs = freezed,Object? health = null,}) {
  return _then(_TailscaleStatus(
node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as TailscaleNode,authUrlReady: null == authUrlReady ? _self.authUrlReady : authUrlReady // ignore: cast_nullable_to_non_nullable
as bool,haveNodeKey: null == haveNodeKey ? _self.haveNodeKey : haveNodeKey // ignore: cast_nullable_to_non_nullable
as bool,self: freezed == self ? _self.self : self // ignore: cast_nullable_to_non_nullable
as TailscalePeer?,loginUser: freezed == loginUser ? _self.loginUser : loginUser // ignore: cast_nullable_to_non_nullable
as TailscaleUser?,tailnet: freezed == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as TailscaleTailnet?,users: null == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as Map<String, TailscaleUser>,peers: null == peers ? _self._peers : peers // ignore: cast_nullable_to_non_nullable
as List<TailscalePeer>,prefs: freezed == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as TailscalePrefs?,health: null == health ? _self._health : health // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleNodeCopyWith<$Res> get node {
  
  return $TailscaleNodeCopyWith<$Res>(_self.node, (value) {
    return _then(_self.copyWith(node: value));
  });
}/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscalePeerCopyWith<$Res>? get self {
    if (_self.self == null) {
    return null;
  }

  return $TailscalePeerCopyWith<$Res>(_self.self!, (value) {
    return _then(_self.copyWith(self: value));
  });
}/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleUserCopyWith<$Res>? get loginUser {
    if (_self.loginUser == null) {
    return null;
  }

  return $TailscaleUserCopyWith<$Res>(_self.loginUser!, (value) {
    return _then(_self.copyWith(loginUser: value));
  });
}/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleTailnetCopyWith<$Res>? get tailnet {
    if (_self.tailnet == null) {
    return null;
  }

  return $TailscaleTailnetCopyWith<$Res>(_self.tailnet!, (value) {
    return _then(_self.copyWith(tailnet: value));
  });
}/// Create a copy of TailscaleStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscalePrefsCopyWith<$Res>? get prefs {
    if (_self.prefs == null) {
    return null;
  }

  return $TailscalePrefsCopyWith<$Res>(_self.prefs!, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}
}


/// @nodoc
mixin _$TailscaleLoginResult {

 int get generation;@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState get state;@JsonKey(name: 'auth-url') String? get authUrl; bool get pending;
/// Create a copy of TailscaleLoginResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleLoginResultCopyWith<TailscaleLoginResult> get copyWith => _$TailscaleLoginResultCopyWithImpl<TailscaleLoginResult>(this as TailscaleLoginResult, _$identity);

  /// Serializes this TailscaleLoginResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleLoginResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleLoginResult&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.authUrl, _this.authUrl) || other.authUrl == _this.authUrl)&&(identical(other.pending, _this.pending) || other.pending == _this.pending));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleLoginResult;
  return Object.hash(runtimeType,_this.generation,_this.state,_this.authUrl,_this.pending);
}

@override
String toString() {
  final _this = this as TailscaleLoginResult;
  return 'TailscaleLoginResult(generation: ${_this.generation}, state: ${_this.state}, authUrl: ${_this.authUrl}, pending: ${_this.pending})';
}


}

/// @nodoc
abstract mixin class $TailscaleLoginResultCopyWith<$Res>  {
  factory $TailscaleLoginResultCopyWith(TailscaleLoginResult value, $Res Function(TailscaleLoginResult) _then) = _$TailscaleLoginResultCopyWithImpl;
@useResult
$Res call({
 int generation,@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState state,@JsonKey(name: 'auth-url') String? authUrl, bool pending
});




}
/// @nodoc
class _$TailscaleLoginResultCopyWithImpl<$Res>
    implements $TailscaleLoginResultCopyWith<$Res> {
  _$TailscaleLoginResultCopyWithImpl(this._self, this._then);

  final TailscaleLoginResult _self;
  final $Res Function(TailscaleLoginResult) _then;

/// Create a copy of TailscaleLoginResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generation = null,Object? state = null,Object? authUrl = freezed,Object? pending = null,}) {
  return _then(TailscaleLoginResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TailscaleBackendState,authUrl: freezed == authUrl ? _self.authUrl : authUrl // ignore: cast_nullable_to_non_nullable
as String?,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleLoginResult].
extension TailscaleLoginResultPatterns on TailscaleLoginResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleLoginResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleLoginResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleLoginResult value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleLoginResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleLoginResult value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleLoginResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState state, @JsonKey(name: 'auth-url')  String? authUrl,  bool pending)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleLoginResult() when $default != null:
return $default(_that.generation,_that.state,_that.authUrl,_that.pending);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState state, @JsonKey(name: 'auth-url')  String? authUrl,  bool pending)  $default,) {final _that = this;
switch (_that) {
case _TailscaleLoginResult():
return $default(_that.generation,_that.state,_that.authUrl,_that.pending);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState state, @JsonKey(name: 'auth-url')  String? authUrl,  bool pending)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleLoginResult() when $default != null:
return $default(_that.generation,_that.state,_that.authUrl,_that.pending);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleLoginResult implements TailscaleLoginResult {
  const _TailscaleLoginResult({required this.generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown) this.state = TailscaleBackendState.none, @JsonKey(name: 'auth-url') this.authUrl, this.pending = false});
  factory _TailscaleLoginResult.fromJson(Map<String, dynamic> json) => _$TailscaleLoginResultFromJson(json);

@override final  int generation;
@override@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) final  TailscaleBackendState state;
@override@JsonKey(name: 'auth-url') final  String? authUrl;
@override@JsonKey() final  bool pending;

/// Create a copy of TailscaleLoginResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleLoginResultCopyWith<_TailscaleLoginResult> get copyWith => __$TailscaleLoginResultCopyWithImpl<_TailscaleLoginResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleLoginResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleLoginResult&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.state, state) || other.state == state)&&(identical(other.authUrl, authUrl) || other.authUrl == authUrl)&&(identical(other.pending, pending) || other.pending == pending));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,generation,state,authUrl,pending);
}

@override
String toString() {
    return 'TailscaleLoginResult(generation: $generation, state: $state, authUrl: $authUrl, pending: $pending)';
}


}

/// @nodoc
abstract mixin class _$TailscaleLoginResultCopyWith<$Res> implements $TailscaleLoginResultCopyWith<$Res> {
  factory _$TailscaleLoginResultCopyWith(_TailscaleLoginResult value, $Res Function(_TailscaleLoginResult) _then) = __$TailscaleLoginResultCopyWithImpl;
@override @useResult
$Res call({
 int generation,@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState state,@JsonKey(name: 'auth-url') String? authUrl, bool pending
});




}
/// @nodoc
class __$TailscaleLoginResultCopyWithImpl<$Res>
    implements _$TailscaleLoginResultCopyWith<$Res> {
  __$TailscaleLoginResultCopyWithImpl(this._self, this._then);

  final _TailscaleLoginResult _self;
  final $Res Function(_TailscaleLoginResult) _then;

/// Create a copy of TailscaleLoginResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generation = null,Object? state = null,Object? authUrl = freezed,Object? pending = null,}) {
  return _then(_TailscaleLoginResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TailscaleBackendState,authUrl: freezed == authUrl ? _self.authUrl : authUrl // ignore: cast_nullable_to_non_nullable
as String?,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TailscaleLogoutResult {

 int get generation;@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState get state;@JsonKey(unknownEnumValue: TailscaleLogoutOutcome.unknown) TailscaleLogoutOutcome get outcome;@JsonKey(name: 'server-confirmed') bool get serverConfirmed;@JsonKey(name: 'identity-cleared') bool get identityCleared; TailscaleError? get error;
/// Create a copy of TailscaleLogoutResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleLogoutResultCopyWith<TailscaleLogoutResult> get copyWith => _$TailscaleLogoutResultCopyWithImpl<TailscaleLogoutResult>(this as TailscaleLogoutResult, _$identity);

  /// Serializes this TailscaleLogoutResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleLogoutResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleLogoutResult&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.serverConfirmed, _this.serverConfirmed) || other.serverConfirmed == _this.serverConfirmed)&&(identical(other.identityCleared, _this.identityCleared) || other.identityCleared == _this.identityCleared)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleLogoutResult;
  return Object.hash(runtimeType,_this.generation,_this.state,_this.outcome,_this.serverConfirmed,_this.identityCleared,_this.error);
}

@override
String toString() {
  final _this = this as TailscaleLogoutResult;
  return 'TailscaleLogoutResult(generation: ${_this.generation}, state: ${_this.state}, outcome: ${_this.outcome}, serverConfirmed: ${_this.serverConfirmed}, identityCleared: ${_this.identityCleared}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $TailscaleLogoutResultCopyWith<$Res>  {
  factory $TailscaleLogoutResultCopyWith(TailscaleLogoutResult value, $Res Function(TailscaleLogoutResult) _then) = _$TailscaleLogoutResultCopyWithImpl;
@useResult
$Res call({
 int generation,@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState state,@JsonKey(unknownEnumValue: TailscaleLogoutOutcome.unknown) TailscaleLogoutOutcome outcome,@JsonKey(name: 'server-confirmed') bool serverConfirmed,@JsonKey(name: 'identity-cleared') bool identityCleared, TailscaleError? error
});


$TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$TailscaleLogoutResultCopyWithImpl<$Res>
    implements $TailscaleLogoutResultCopyWith<$Res> {
  _$TailscaleLogoutResultCopyWithImpl(this._self, this._then);

  final TailscaleLogoutResult _self;
  final $Res Function(TailscaleLogoutResult) _then;

/// Create a copy of TailscaleLogoutResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generation = null,Object? state = null,Object? outcome = null,Object? serverConfirmed = null,Object? identityCleared = null,Object? error = freezed,}) {
  return _then(TailscaleLogoutResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TailscaleBackendState,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as TailscaleLogoutOutcome,serverConfirmed: null == serverConfirmed ? _self.serverConfirmed : serverConfirmed // ignore: cast_nullable_to_non_nullable
as bool,identityCleared: null == identityCleared ? _self.identityCleared : identityCleared // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}
/// Create a copy of TailscaleLogoutResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleLogoutResult].
extension TailscaleLogoutResultPatterns on TailscaleLogoutResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleLogoutResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleLogoutResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleLogoutResult value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleLogoutResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleLogoutResult value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleLogoutResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState state, @JsonKey(unknownEnumValue: TailscaleLogoutOutcome.unknown)  TailscaleLogoutOutcome outcome, @JsonKey(name: 'server-confirmed')  bool serverConfirmed, @JsonKey(name: 'identity-cleared')  bool identityCleared,  TailscaleError? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleLogoutResult() when $default != null:
return $default(_that.generation,_that.state,_that.outcome,_that.serverConfirmed,_that.identityCleared,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState state, @JsonKey(unknownEnumValue: TailscaleLogoutOutcome.unknown)  TailscaleLogoutOutcome outcome, @JsonKey(name: 'server-confirmed')  bool serverConfirmed, @JsonKey(name: 'identity-cleared')  bool identityCleared,  TailscaleError? error)  $default,) {final _that = this;
switch (_that) {
case _TailscaleLogoutResult():
return $default(_that.generation,_that.state,_that.outcome,_that.serverConfirmed,_that.identityCleared,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState state, @JsonKey(unknownEnumValue: TailscaleLogoutOutcome.unknown)  TailscaleLogoutOutcome outcome, @JsonKey(name: 'server-confirmed')  bool serverConfirmed, @JsonKey(name: 'identity-cleared')  bool identityCleared,  TailscaleError? error)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleLogoutResult() when $default != null:
return $default(_that.generation,_that.state,_that.outcome,_that.serverConfirmed,_that.identityCleared,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleLogoutResult implements TailscaleLogoutResult {
  const _TailscaleLogoutResult({required this.generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown) this.state = TailscaleBackendState.none, @JsonKey(unknownEnumValue: TailscaleLogoutOutcome.unknown) this.outcome = TailscaleLogoutOutcome.unknown, @JsonKey(name: 'server-confirmed') this.serverConfirmed = false, @JsonKey(name: 'identity-cleared') this.identityCleared = false, this.error});
  factory _TailscaleLogoutResult.fromJson(Map<String, dynamic> json) => _$TailscaleLogoutResultFromJson(json);

@override final  int generation;
@override@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) final  TailscaleBackendState state;
@override@JsonKey(unknownEnumValue: TailscaleLogoutOutcome.unknown) final  TailscaleLogoutOutcome outcome;
@override@JsonKey(name: 'server-confirmed') final  bool serverConfirmed;
@override@JsonKey(name: 'identity-cleared') final  bool identityCleared;
@override final  TailscaleError? error;

/// Create a copy of TailscaleLogoutResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleLogoutResultCopyWith<_TailscaleLogoutResult> get copyWith => __$TailscaleLogoutResultCopyWithImpl<_TailscaleLogoutResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleLogoutResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleLogoutResult&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.state, state) || other.state == state)&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.serverConfirmed, serverConfirmed) || other.serverConfirmed == serverConfirmed)&&(identical(other.identityCleared, identityCleared) || other.identityCleared == identityCleared)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,generation,state,outcome,serverConfirmed,identityCleared,error);
}

@override
String toString() {
    return 'TailscaleLogoutResult(generation: $generation, state: $state, outcome: $outcome, serverConfirmed: $serverConfirmed, identityCleared: $identityCleared, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TailscaleLogoutResultCopyWith<$Res> implements $TailscaleLogoutResultCopyWith<$Res> {
  factory _$TailscaleLogoutResultCopyWith(_TailscaleLogoutResult value, $Res Function(_TailscaleLogoutResult) _then) = __$TailscaleLogoutResultCopyWithImpl;
@override @useResult
$Res call({
 int generation,@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState state,@JsonKey(unknownEnumValue: TailscaleLogoutOutcome.unknown) TailscaleLogoutOutcome outcome,@JsonKey(name: 'server-confirmed') bool serverConfirmed,@JsonKey(name: 'identity-cleared') bool identityCleared, TailscaleError? error
});


@override $TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class __$TailscaleLogoutResultCopyWithImpl<$Res>
    implements _$TailscaleLogoutResultCopyWith<$Res> {
  __$TailscaleLogoutResultCopyWithImpl(this._self, this._then);

  final _TailscaleLogoutResult _self;
  final $Res Function(_TailscaleLogoutResult) _then;

/// Create a copy of TailscaleLogoutResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generation = null,Object? state = null,Object? outcome = null,Object? serverConfirmed = null,Object? identityCleared = null,Object? error = freezed,}) {
  return _then(_TailscaleLogoutResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TailscaleBackendState,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as TailscaleLogoutOutcome,serverConfirmed: null == serverConfirmed ? _self.serverConfirmed : serverConfirmed // ignore: cast_nullable_to_non_nullable
as bool,identityCleared: null == identityCleared ? _self.identityCleared : identityCleared // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}

/// Create a copy of TailscaleLogoutResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$TailscalePrefsResult {

 int get generation;@JsonKey(unknownEnumValue: TailscalePrefsOutcome.unknown) TailscalePrefsOutcome get outcome; TailscalePrefs? get prefs; TailscaleError? get error;
/// Create a copy of TailscalePrefsResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscalePrefsResultCopyWith<TailscalePrefsResult> get copyWith => _$TailscalePrefsResultCopyWithImpl<TailscalePrefsResult>(this as TailscalePrefsResult, _$identity);

  /// Serializes this TailscalePrefsResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscalePrefsResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscalePrefsResult&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.prefs, _this.prefs) || other.prefs == _this.prefs)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscalePrefsResult;
  return Object.hash(runtimeType,_this.generation,_this.outcome,_this.prefs,_this.error);
}

@override
String toString() {
  final _this = this as TailscalePrefsResult;
  return 'TailscalePrefsResult(generation: ${_this.generation}, outcome: ${_this.outcome}, prefs: ${_this.prefs}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $TailscalePrefsResultCopyWith<$Res>  {
  factory $TailscalePrefsResultCopyWith(TailscalePrefsResult value, $Res Function(TailscalePrefsResult) _then) = _$TailscalePrefsResultCopyWithImpl;
@useResult
$Res call({
 int generation,@JsonKey(unknownEnumValue: TailscalePrefsOutcome.unknown) TailscalePrefsOutcome outcome, TailscalePrefs? prefs, TailscaleError? error
});


$TailscalePrefsCopyWith<$Res>? get prefs;$TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$TailscalePrefsResultCopyWithImpl<$Res>
    implements $TailscalePrefsResultCopyWith<$Res> {
  _$TailscalePrefsResultCopyWithImpl(this._self, this._then);

  final TailscalePrefsResult _self;
  final $Res Function(TailscalePrefsResult) _then;

/// Create a copy of TailscalePrefsResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generation = null,Object? outcome = null,Object? prefs = freezed,Object? error = freezed,}) {
  return _then(TailscalePrefsResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as TailscalePrefsOutcome,prefs: freezed == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as TailscalePrefs?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}
/// Create a copy of TailscalePrefsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscalePrefsCopyWith<$Res>? get prefs {
    if (_self.prefs == null) {
    return null;
  }

  return $TailscalePrefsCopyWith<$Res>(_self.prefs!, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}/// Create a copy of TailscalePrefsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscalePrefsResult].
extension TailscalePrefsResultPatterns on TailscalePrefsResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscalePrefsResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscalePrefsResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscalePrefsResult value)  $default,){
final _that = this;
switch (_that) {
case _TailscalePrefsResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscalePrefsResult value)?  $default,){
final _that = this;
switch (_that) {
case _TailscalePrefsResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int generation, @JsonKey(unknownEnumValue: TailscalePrefsOutcome.unknown)  TailscalePrefsOutcome outcome,  TailscalePrefs? prefs,  TailscaleError? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscalePrefsResult() when $default != null:
return $default(_that.generation,_that.outcome,_that.prefs,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int generation, @JsonKey(unknownEnumValue: TailscalePrefsOutcome.unknown)  TailscalePrefsOutcome outcome,  TailscalePrefs? prefs,  TailscaleError? error)  $default,) {final _that = this;
switch (_that) {
case _TailscalePrefsResult():
return $default(_that.generation,_that.outcome,_that.prefs,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int generation, @JsonKey(unknownEnumValue: TailscalePrefsOutcome.unknown)  TailscalePrefsOutcome outcome,  TailscalePrefs? prefs,  TailscaleError? error)?  $default,) {final _that = this;
switch (_that) {
case _TailscalePrefsResult() when $default != null:
return $default(_that.generation,_that.outcome,_that.prefs,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscalePrefsResult implements TailscalePrefsResult {
  const _TailscalePrefsResult({required this.generation, @JsonKey(unknownEnumValue: TailscalePrefsOutcome.unknown) this.outcome = TailscalePrefsOutcome.unknown, this.prefs, this.error});
  factory _TailscalePrefsResult.fromJson(Map<String, dynamic> json) => _$TailscalePrefsResultFromJson(json);

@override final  int generation;
@override@JsonKey(unknownEnumValue: TailscalePrefsOutcome.unknown) final  TailscalePrefsOutcome outcome;
@override final  TailscalePrefs? prefs;
@override final  TailscaleError? error;

/// Create a copy of TailscalePrefsResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscalePrefsResultCopyWith<_TailscalePrefsResult> get copyWith => __$TailscalePrefsResultCopyWithImpl<_TailscalePrefsResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscalePrefsResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscalePrefsResult&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.prefs, prefs) || other.prefs == prefs)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,generation,outcome,prefs,error);
}

@override
String toString() {
    return 'TailscalePrefsResult(generation: $generation, outcome: $outcome, prefs: $prefs, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TailscalePrefsResultCopyWith<$Res> implements $TailscalePrefsResultCopyWith<$Res> {
  factory _$TailscalePrefsResultCopyWith(_TailscalePrefsResult value, $Res Function(_TailscalePrefsResult) _then) = __$TailscalePrefsResultCopyWithImpl;
@override @useResult
$Res call({
 int generation,@JsonKey(unknownEnumValue: TailscalePrefsOutcome.unknown) TailscalePrefsOutcome outcome, TailscalePrefs? prefs, TailscaleError? error
});


@override $TailscalePrefsCopyWith<$Res>? get prefs;@override $TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class __$TailscalePrefsResultCopyWithImpl<$Res>
    implements _$TailscalePrefsResultCopyWith<$Res> {
  __$TailscalePrefsResultCopyWithImpl(this._self, this._then);

  final _TailscalePrefsResult _self;
  final $Res Function(_TailscalePrefsResult) _then;

/// Create a copy of TailscalePrefsResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generation = null,Object? outcome = null,Object? prefs = freezed,Object? error = freezed,}) {
  return _then(_TailscalePrefsResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as TailscalePrefsOutcome,prefs: freezed == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as TailscalePrefs?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}

/// Create a copy of TailscalePrefsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscalePrefsCopyWith<$Res>? get prefs {
    if (_self.prefs == null) {
    return null;
  }

  return $TailscalePrefsCopyWith<$Res>(_self.prefs!, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}/// Create a copy of TailscalePrefsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$TailscaleStateEvent {

 String get name; int get generation;@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState get state;@JsonKey(name: 'auth-url-ready') bool get authUrlReady;
/// Create a copy of TailscaleStateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleStateEventCopyWith<TailscaleStateEvent> get copyWith => _$TailscaleStateEventCopyWithImpl<TailscaleStateEvent>(this as TailscaleStateEvent, _$identity);

  /// Serializes this TailscaleStateEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleStateEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleStateEvent&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.authUrlReady, _this.authUrlReady) || other.authUrlReady == _this.authUrlReady));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleStateEvent;
  return Object.hash(runtimeType,_this.name,_this.generation,_this.state,_this.authUrlReady);
}

@override
String toString() {
  final _this = this as TailscaleStateEvent;
  return 'TailscaleStateEvent(name: ${_this.name}, generation: ${_this.generation}, state: ${_this.state}, authUrlReady: ${_this.authUrlReady})';
}


}

/// @nodoc
abstract mixin class $TailscaleStateEventCopyWith<$Res>  {
  factory $TailscaleStateEventCopyWith(TailscaleStateEvent value, $Res Function(TailscaleStateEvent) _then) = _$TailscaleStateEventCopyWithImpl;
@useResult
$Res call({
 String name, int generation,@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState state,@JsonKey(name: 'auth-url-ready') bool authUrlReady
});




}
/// @nodoc
class _$TailscaleStateEventCopyWithImpl<$Res>
    implements $TailscaleStateEventCopyWith<$Res> {
  _$TailscaleStateEventCopyWithImpl(this._self, this._then);

  final TailscaleStateEvent _self;
  final $Res Function(TailscaleStateEvent) _then;

/// Create a copy of TailscaleStateEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? generation = null,Object? state = null,Object? authUrlReady = null,}) {
  return _then(TailscaleStateEvent(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TailscaleBackendState,authUrlReady: null == authUrlReady ? _self.authUrlReady : authUrlReady // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleStateEvent].
extension TailscaleStateEventPatterns on TailscaleStateEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleStateEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleStateEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleStateEvent value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleStateEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleStateEvent value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleStateEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState state, @JsonKey(name: 'auth-url-ready')  bool authUrlReady)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleStateEvent() when $default != null:
return $default(_that.name,_that.generation,_that.state,_that.authUrlReady);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState state, @JsonKey(name: 'auth-url-ready')  bool authUrlReady)  $default,) {final _that = this;
switch (_that) {
case _TailscaleStateEvent():
return $default(_that.name,_that.generation,_that.state,_that.authUrlReady);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown)  TailscaleBackendState state, @JsonKey(name: 'auth-url-ready')  bool authUrlReady)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleStateEvent() when $default != null:
return $default(_that.name,_that.generation,_that.state,_that.authUrlReady);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleStateEvent implements TailscaleStateEvent {
  const _TailscaleStateEvent({required this.name, required this.generation, @JsonKey(unknownEnumValue: TailscaleBackendState.unknown) this.state = TailscaleBackendState.none, @JsonKey(name: 'auth-url-ready') this.authUrlReady = false});
  factory _TailscaleStateEvent.fromJson(Map<String, dynamic> json) => _$TailscaleStateEventFromJson(json);

@override final  String name;
@override final  int generation;
@override@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) final  TailscaleBackendState state;
@override@JsonKey(name: 'auth-url-ready') final  bool authUrlReady;

/// Create a copy of TailscaleStateEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleStateEventCopyWith<_TailscaleStateEvent> get copyWith => __$TailscaleStateEventCopyWithImpl<_TailscaleStateEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleStateEventToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleStateEvent&&(identical(other.name, name) || other.name == name)&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.state, state) || other.state == state)&&(identical(other.authUrlReady, authUrlReady) || other.authUrlReady == authUrlReady));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,generation,state,authUrlReady);
}

@override
String toString() {
    return 'TailscaleStateEvent(name: $name, generation: $generation, state: $state, authUrlReady: $authUrlReady)';
}


}

/// @nodoc
abstract mixin class _$TailscaleStateEventCopyWith<$Res> implements $TailscaleStateEventCopyWith<$Res> {
  factory _$TailscaleStateEventCopyWith(_TailscaleStateEvent value, $Res Function(_TailscaleStateEvent) _then) = __$TailscaleStateEventCopyWithImpl;
@override @useResult
$Res call({
 String name, int generation,@JsonKey(unknownEnumValue: TailscaleBackendState.unknown) TailscaleBackendState state,@JsonKey(name: 'auth-url-ready') bool authUrlReady
});




}
/// @nodoc
class __$TailscaleStateEventCopyWithImpl<$Res>
    implements _$TailscaleStateEventCopyWith<$Res> {
  __$TailscaleStateEventCopyWithImpl(this._self, this._then);

  final _TailscaleStateEvent _self;
  final $Res Function(_TailscaleStateEvent) _then;

/// Create a copy of TailscaleStateEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? generation = null,Object? state = null,Object? authUrlReady = null,}) {
  return _then(_TailscaleStateEvent(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TailscaleBackendState,authUrlReady: null == authUrlReady ? _self.authUrlReady : authUrlReady // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TailscaleNodeRecord {

@JsonKey(name: 'profile-id') int get profileId; String get name;@JsonKey(name: 'control-url') String get controlUrl;@JsonKey(name: 'exit-node', includeIfNull: false) String? get exitNode;@JsonKey(name: 'exit-node-name', includeIfNull: false) String? get exitNodeName;@JsonKey(name: 'accept-routes', includeIfNull: false) bool? get acceptRoutes;@JsonKey(name: 'logged-out') bool get loggedOut;
/// Create a copy of TailscaleNodeRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleNodeRecordCopyWith<TailscaleNodeRecord> get copyWith => _$TailscaleNodeRecordCopyWithImpl<TailscaleNodeRecord>(this as TailscaleNodeRecord, _$identity);

  /// Serializes this TailscaleNodeRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleNodeRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleNodeRecord&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl)&&(identical(other.exitNode, _this.exitNode) || other.exitNode == _this.exitNode)&&(identical(other.exitNodeName, _this.exitNodeName) || other.exitNodeName == _this.exitNodeName)&&(identical(other.acceptRoutes, _this.acceptRoutes) || other.acceptRoutes == _this.acceptRoutes)&&(identical(other.loggedOut, _this.loggedOut) || other.loggedOut == _this.loggedOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleNodeRecord;
  return Object.hash(runtimeType,_this.profileId,_this.name,_this.controlUrl,_this.exitNode,_this.exitNodeName,_this.acceptRoutes,_this.loggedOut);
}

@override
String toString() {
  final _this = this as TailscaleNodeRecord;
  return 'TailscaleNodeRecord(profileId: ${_this.profileId}, name: ${_this.name}, controlUrl: ${_this.controlUrl}, exitNode: ${_this.exitNode}, exitNodeName: ${_this.exitNodeName}, acceptRoutes: ${_this.acceptRoutes}, loggedOut: ${_this.loggedOut})';
}


}

/// @nodoc
abstract mixin class $TailscaleNodeRecordCopyWith<$Res>  {
  factory $TailscaleNodeRecordCopyWith(TailscaleNodeRecord value, $Res Function(TailscaleNodeRecord) _then) = _$TailscaleNodeRecordCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId, String name,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,@JsonKey(name: 'exit-node-name', includeIfNull: false) String? exitNodeName,@JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,@JsonKey(name: 'logged-out') bool loggedOut
});




}
/// @nodoc
class _$TailscaleNodeRecordCopyWithImpl<$Res>
    implements $TailscaleNodeRecordCopyWith<$Res> {
  _$TailscaleNodeRecordCopyWithImpl(this._self, this._then);

  final TailscaleNodeRecord _self;
  final $Res Function(TailscaleNodeRecord) _then;

/// Create a copy of TailscaleNodeRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? name = null,Object? controlUrl = null,Object? exitNode = freezed,Object? exitNodeName = freezed,Object? acceptRoutes = freezed,Object? loggedOut = null,}) {
  return _then(TailscaleNodeRecord(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,exitNode: freezed == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String?,exitNodeName: freezed == exitNodeName ? _self.exitNodeName : exitNodeName // ignore: cast_nullable_to_non_nullable
as String?,acceptRoutes: freezed == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool?,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleNodeRecord].
extension TailscaleNodeRecordPatterns on TailscaleNodeRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleNodeRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleNodeRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleNodeRecord value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleNodeRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleNodeRecord value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleNodeRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId,  String name, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'exit-node-name', includeIfNull: false)  String? exitNodeName, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleNodeRecord() when $default != null:
return $default(_that.profileId,_that.name,_that.controlUrl,_that.exitNode,_that.exitNodeName,_that.acceptRoutes,_that.loggedOut);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId,  String name, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'exit-node-name', includeIfNull: false)  String? exitNodeName, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut)  $default,) {final _that = this;
switch (_that) {
case _TailscaleNodeRecord():
return $default(_that.profileId,_that.name,_that.controlUrl,_that.exitNode,_that.exitNodeName,_that.acceptRoutes,_that.loggedOut);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'profile-id')  int profileId,  String name, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'exit-node-name', includeIfNull: false)  String? exitNodeName, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleNodeRecord() when $default != null:
return $default(_that.profileId,_that.name,_that.controlUrl,_that.exitNode,_that.exitNodeName,_that.acceptRoutes,_that.loggedOut);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleNodeRecord extends TailscaleNodeRecord {
  const _TailscaleNodeRecord({@JsonKey(name: 'profile-id') required this.profileId, required this.name, @JsonKey(name: 'control-url') this.controlUrl = '', @JsonKey(name: 'exit-node', includeIfNull: false) this.exitNode, @JsonKey(name: 'exit-node-name', includeIfNull: false) this.exitNodeName, @JsonKey(name: 'accept-routes', includeIfNull: false) this.acceptRoutes, @JsonKey(name: 'logged-out') this.loggedOut = false}): super._();
  factory _TailscaleNodeRecord.fromJson(Map<String, dynamic> json) => _$TailscaleNodeRecordFromJson(json);

@override@JsonKey(name: 'profile-id') final  int profileId;
@override final  String name;
@override@JsonKey(name: 'control-url') final  String controlUrl;
@override@JsonKey(name: 'exit-node', includeIfNull: false) final  String? exitNode;
@override@JsonKey(name: 'exit-node-name', includeIfNull: false) final  String? exitNodeName;
@override@JsonKey(name: 'accept-routes', includeIfNull: false) final  bool? acceptRoutes;
@override@JsonKey(name: 'logged-out') final  bool loggedOut;

/// Create a copy of TailscaleNodeRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleNodeRecordCopyWith<_TailscaleNodeRecord> get copyWith => __$TailscaleNodeRecordCopyWithImpl<_TailscaleNodeRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleNodeRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleNodeRecord&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.name, name) || other.name == name)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl)&&(identical(other.exitNode, exitNode) || other.exitNode == exitNode)&&(identical(other.exitNodeName, exitNodeName) || other.exitNodeName == exitNodeName)&&(identical(other.acceptRoutes, acceptRoutes) || other.acceptRoutes == acceptRoutes)&&(identical(other.loggedOut, loggedOut) || other.loggedOut == loggedOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,profileId,name,controlUrl,exitNode,exitNodeName,acceptRoutes,loggedOut);
}

@override
String toString() {
    return 'TailscaleNodeRecord(profileId: $profileId, name: $name, controlUrl: $controlUrl, exitNode: $exitNode, exitNodeName: $exitNodeName, acceptRoutes: $acceptRoutes, loggedOut: $loggedOut)';
}


}

/// @nodoc
abstract mixin class _$TailscaleNodeRecordCopyWith<$Res> implements $TailscaleNodeRecordCopyWith<$Res> {
  factory _$TailscaleNodeRecordCopyWith(_TailscaleNodeRecord value, $Res Function(_TailscaleNodeRecord) _then) = __$TailscaleNodeRecordCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId, String name,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,@JsonKey(name: 'exit-node-name', includeIfNull: false) String? exitNodeName,@JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,@JsonKey(name: 'logged-out') bool loggedOut
});




}
/// @nodoc
class __$TailscaleNodeRecordCopyWithImpl<$Res>
    implements _$TailscaleNodeRecordCopyWith<$Res> {
  __$TailscaleNodeRecordCopyWithImpl(this._self, this._then);

  final _TailscaleNodeRecord _self;
  final $Res Function(_TailscaleNodeRecord) _then;

/// Create a copy of TailscaleNodeRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? name = null,Object? controlUrl = null,Object? exitNode = freezed,Object? exitNodeName = freezed,Object? acceptRoutes = freezed,Object? loggedOut = null,}) {
  return _then(_TailscaleNodeRecord(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,exitNode: freezed == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String?,exitNodeName: freezed == exitNodeName ? _self.exitNodeName : exitNodeName // ignore: cast_nullable_to_non_nullable
as String?,acceptRoutes: freezed == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool?,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TailscaleNodeSetup {

 String get name;@JsonKey(name: 'control-url') String get controlUrl;@JsonKey(name: 'exit-node', includeIfNull: false) String? get exitNode;@JsonKey(name: 'accept-routes', includeIfNull: false) bool? get acceptRoutes;@JsonKey(name: 'logged-out') bool get loggedOut;
/// Create a copy of TailscaleNodeSetup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleNodeSetupCopyWith<TailscaleNodeSetup> get copyWith => _$TailscaleNodeSetupCopyWithImpl<TailscaleNodeSetup>(this as TailscaleNodeSetup, _$identity);

  /// Serializes this TailscaleNodeSetup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleNodeSetup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleNodeSetup&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl)&&(identical(other.exitNode, _this.exitNode) || other.exitNode == _this.exitNode)&&(identical(other.acceptRoutes, _this.acceptRoutes) || other.acceptRoutes == _this.acceptRoutes)&&(identical(other.loggedOut, _this.loggedOut) || other.loggedOut == _this.loggedOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleNodeSetup;
  return Object.hash(runtimeType,_this.name,_this.controlUrl,_this.exitNode,_this.acceptRoutes,_this.loggedOut);
}

@override
String toString() {
  final _this = this as TailscaleNodeSetup;
  return 'TailscaleNodeSetup(name: ${_this.name}, controlUrl: ${_this.controlUrl}, exitNode: ${_this.exitNode}, acceptRoutes: ${_this.acceptRoutes}, loggedOut: ${_this.loggedOut})';
}


}

/// @nodoc
abstract mixin class $TailscaleNodeSetupCopyWith<$Res>  {
  factory $TailscaleNodeSetupCopyWith(TailscaleNodeSetup value, $Res Function(TailscaleNodeSetup) _then) = _$TailscaleNodeSetupCopyWithImpl;
@useResult
$Res call({
 String name,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,@JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,@JsonKey(name: 'logged-out') bool loggedOut
});




}
/// @nodoc
class _$TailscaleNodeSetupCopyWithImpl<$Res>
    implements $TailscaleNodeSetupCopyWith<$Res> {
  _$TailscaleNodeSetupCopyWithImpl(this._self, this._then);

  final TailscaleNodeSetup _self;
  final $Res Function(TailscaleNodeSetup) _then;

/// Create a copy of TailscaleNodeSetup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? controlUrl = null,Object? exitNode = freezed,Object? acceptRoutes = freezed,Object? loggedOut = null,}) {
  return _then(TailscaleNodeSetup(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,exitNode: freezed == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String?,acceptRoutes: freezed == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool?,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleNodeSetup].
extension TailscaleNodeSetupPatterns on TailscaleNodeSetup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleNodeSetup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleNodeSetup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleNodeSetup value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleNodeSetup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleNodeSetup value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleNodeSetup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleNodeSetup() when $default != null:
return $default(_that.name,_that.controlUrl,_that.exitNode,_that.acceptRoutes,_that.loggedOut);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut)  $default,) {final _that = this;
switch (_that) {
case _TailscaleNodeSetup():
return $default(_that.name,_that.controlUrl,_that.exitNode,_that.acceptRoutes,_that.loggedOut);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleNodeSetup() when $default != null:
return $default(_that.name,_that.controlUrl,_that.exitNode,_that.acceptRoutes,_that.loggedOut);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleNodeSetup implements TailscaleNodeSetup {
  const _TailscaleNodeSetup({required this.name, @JsonKey(name: 'control-url') this.controlUrl = '', @JsonKey(name: 'exit-node', includeIfNull: false) this.exitNode, @JsonKey(name: 'accept-routes', includeIfNull: false) this.acceptRoutes, @JsonKey(name: 'logged-out') this.loggedOut = false});
  factory _TailscaleNodeSetup.fromJson(Map<String, dynamic> json) => _$TailscaleNodeSetupFromJson(json);

@override final  String name;
@override@JsonKey(name: 'control-url') final  String controlUrl;
@override@JsonKey(name: 'exit-node', includeIfNull: false) final  String? exitNode;
@override@JsonKey(name: 'accept-routes', includeIfNull: false) final  bool? acceptRoutes;
@override@JsonKey(name: 'logged-out') final  bool loggedOut;

/// Create a copy of TailscaleNodeSetup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleNodeSetupCopyWith<_TailscaleNodeSetup> get copyWith => __$TailscaleNodeSetupCopyWithImpl<_TailscaleNodeSetup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleNodeSetupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleNodeSetup&&(identical(other.name, name) || other.name == name)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl)&&(identical(other.exitNode, exitNode) || other.exitNode == exitNode)&&(identical(other.acceptRoutes, acceptRoutes) || other.acceptRoutes == acceptRoutes)&&(identical(other.loggedOut, loggedOut) || other.loggedOut == loggedOut));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,controlUrl,exitNode,acceptRoutes,loggedOut);
}

@override
String toString() {
    return 'TailscaleNodeSetup(name: $name, controlUrl: $controlUrl, exitNode: $exitNode, acceptRoutes: $acceptRoutes, loggedOut: $loggedOut)';
}


}

/// @nodoc
abstract mixin class _$TailscaleNodeSetupCopyWith<$Res> implements $TailscaleNodeSetupCopyWith<$Res> {
  factory _$TailscaleNodeSetupCopyWith(_TailscaleNodeSetup value, $Res Function(_TailscaleNodeSetup) _then) = __$TailscaleNodeSetupCopyWithImpl;
@override @useResult
$Res call({
 String name,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,@JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,@JsonKey(name: 'logged-out') bool loggedOut
});




}
/// @nodoc
class __$TailscaleNodeSetupCopyWithImpl<$Res>
    implements _$TailscaleNodeSetupCopyWith<$Res> {
  __$TailscaleNodeSetupCopyWithImpl(this._self, this._then);

  final _TailscaleNodeSetup _self;
  final $Res Function(_TailscaleNodeSetup) _then;

/// Create a copy of TailscaleNodeSetup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? controlUrl = null,Object? exitNode = freezed,Object? acceptRoutes = freezed,Object? loggedOut = null,}) {
  return _then(_TailscaleNodeSetup(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,exitNode: freezed == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String?,acceptRoutes: freezed == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool?,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TailscaleManagedRecord {

 String get id;@JsonKey(name: 'profile-id') int get profileId;@JsonKey(name: 'control-url') String get controlUrl;@JsonKey(name: 'exit-node', includeIfNull: false) String? get exitNode;@JsonKey(name: 'exit-node-name', includeIfNull: false) String? get exitNodeName;@JsonKey(name: 'accept-routes', includeIfNull: false) bool? get acceptRoutes;@JsonKey(name: 'logged-out') bool get loggedOut; bool get attached;/// A removal was started and its outcome is not known yet; it blocks a
/// new sign-in, a second removal and deleting the profile.
 bool get removing;
/// Create a copy of TailscaleManagedRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleManagedRecordCopyWith<TailscaleManagedRecord> get copyWith => _$TailscaleManagedRecordCopyWithImpl<TailscaleManagedRecord>(this as TailscaleManagedRecord, _$identity);

  /// Serializes this TailscaleManagedRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleManagedRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleManagedRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl)&&(identical(other.exitNode, _this.exitNode) || other.exitNode == _this.exitNode)&&(identical(other.exitNodeName, _this.exitNodeName) || other.exitNodeName == _this.exitNodeName)&&(identical(other.acceptRoutes, _this.acceptRoutes) || other.acceptRoutes == _this.acceptRoutes)&&(identical(other.loggedOut, _this.loggedOut) || other.loggedOut == _this.loggedOut)&&(identical(other.attached, _this.attached) || other.attached == _this.attached)&&(identical(other.removing, _this.removing) || other.removing == _this.removing));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleManagedRecord;
  return Object.hash(runtimeType,_this.id,_this.profileId,_this.controlUrl,_this.exitNode,_this.exitNodeName,_this.acceptRoutes,_this.loggedOut,_this.attached,_this.removing);
}

@override
String toString() {
  final _this = this as TailscaleManagedRecord;
  return 'TailscaleManagedRecord(id: ${_this.id}, profileId: ${_this.profileId}, controlUrl: ${_this.controlUrl}, exitNode: ${_this.exitNode}, exitNodeName: ${_this.exitNodeName}, acceptRoutes: ${_this.acceptRoutes}, loggedOut: ${_this.loggedOut}, attached: ${_this.attached}, removing: ${_this.removing})';
}


}

/// @nodoc
abstract mixin class $TailscaleManagedRecordCopyWith<$Res>  {
  factory $TailscaleManagedRecordCopyWith(TailscaleManagedRecord value, $Res Function(TailscaleManagedRecord) _then) = _$TailscaleManagedRecordCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'profile-id') int profileId,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,@JsonKey(name: 'exit-node-name', includeIfNull: false) String? exitNodeName,@JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,@JsonKey(name: 'logged-out') bool loggedOut, bool attached, bool removing
});




}
/// @nodoc
class _$TailscaleManagedRecordCopyWithImpl<$Res>
    implements $TailscaleManagedRecordCopyWith<$Res> {
  _$TailscaleManagedRecordCopyWithImpl(this._self, this._then);

  final TailscaleManagedRecord _self;
  final $Res Function(TailscaleManagedRecord) _then;

/// Create a copy of TailscaleManagedRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? profileId = null,Object? controlUrl = null,Object? exitNode = freezed,Object? exitNodeName = freezed,Object? acceptRoutes = freezed,Object? loggedOut = null,Object? attached = null,Object? removing = null,}) {
  return _then(TailscaleManagedRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,exitNode: freezed == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String?,exitNodeName: freezed == exitNodeName ? _self.exitNodeName : exitNodeName // ignore: cast_nullable_to_non_nullable
as String?,acceptRoutes: freezed == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool?,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,attached: null == attached ? _self.attached : attached // ignore: cast_nullable_to_non_nullable
as bool,removing: null == removing ? _self.removing : removing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleManagedRecord].
extension TailscaleManagedRecordPatterns on TailscaleManagedRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleManagedRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleManagedRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleManagedRecord value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleManagedRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleManagedRecord value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleManagedRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'profile-id')  int profileId, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'exit-node-name', includeIfNull: false)  String? exitNodeName, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut,  bool attached,  bool removing)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleManagedRecord() when $default != null:
return $default(_that.id,_that.profileId,_that.controlUrl,_that.exitNode,_that.exitNodeName,_that.acceptRoutes,_that.loggedOut,_that.attached,_that.removing);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'profile-id')  int profileId, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'exit-node-name', includeIfNull: false)  String? exitNodeName, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut,  bool attached,  bool removing)  $default,) {final _that = this;
switch (_that) {
case _TailscaleManagedRecord():
return $default(_that.id,_that.profileId,_that.controlUrl,_that.exitNode,_that.exitNodeName,_that.acceptRoutes,_that.loggedOut,_that.attached,_that.removing);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'profile-id')  int profileId, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'exit-node-name', includeIfNull: false)  String? exitNodeName, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut,  bool attached,  bool removing)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleManagedRecord() when $default != null:
return $default(_that.id,_that.profileId,_that.controlUrl,_that.exitNode,_that.exitNodeName,_that.acceptRoutes,_that.loggedOut,_that.attached,_that.removing);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleManagedRecord extends TailscaleManagedRecord {
  const _TailscaleManagedRecord({required this.id, @JsonKey(name: 'profile-id') required this.profileId, @JsonKey(name: 'control-url') this.controlUrl = '', @JsonKey(name: 'exit-node', includeIfNull: false) this.exitNode, @JsonKey(name: 'exit-node-name', includeIfNull: false) this.exitNodeName, @JsonKey(name: 'accept-routes', includeIfNull: false) this.acceptRoutes, @JsonKey(name: 'logged-out') this.loggedOut = false, this.attached = false, this.removing = false}): super._();
  factory _TailscaleManagedRecord.fromJson(Map<String, dynamic> json) => _$TailscaleManagedRecordFromJson(json);

@override final  String id;
@override@JsonKey(name: 'profile-id') final  int profileId;
@override@JsonKey(name: 'control-url') final  String controlUrl;
@override@JsonKey(name: 'exit-node', includeIfNull: false) final  String? exitNode;
@override@JsonKey(name: 'exit-node-name', includeIfNull: false) final  String? exitNodeName;
@override@JsonKey(name: 'accept-routes', includeIfNull: false) final  bool? acceptRoutes;
@override@JsonKey(name: 'logged-out') final  bool loggedOut;
@override@JsonKey() final  bool attached;
/// A removal was started and its outcome is not known yet; it blocks a
/// new sign-in, a second removal and deleting the profile.
@override@JsonKey() final  bool removing;

/// Create a copy of TailscaleManagedRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleManagedRecordCopyWith<_TailscaleManagedRecord> get copyWith => __$TailscaleManagedRecordCopyWithImpl<_TailscaleManagedRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleManagedRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleManagedRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl)&&(identical(other.exitNode, exitNode) || other.exitNode == exitNode)&&(identical(other.exitNodeName, exitNodeName) || other.exitNodeName == exitNodeName)&&(identical(other.acceptRoutes, acceptRoutes) || other.acceptRoutes == acceptRoutes)&&(identical(other.loggedOut, loggedOut) || other.loggedOut == loggedOut)&&(identical(other.attached, attached) || other.attached == attached)&&(identical(other.removing, removing) || other.removing == removing));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,profileId,controlUrl,exitNode,exitNodeName,acceptRoutes,loggedOut,attached,removing);
}

@override
String toString() {
    return 'TailscaleManagedRecord(id: $id, profileId: $profileId, controlUrl: $controlUrl, exitNode: $exitNode, exitNodeName: $exitNodeName, acceptRoutes: $acceptRoutes, loggedOut: $loggedOut, attached: $attached, removing: $removing)';
}


}

/// @nodoc
abstract mixin class _$TailscaleManagedRecordCopyWith<$Res> implements $TailscaleManagedRecordCopyWith<$Res> {
  factory _$TailscaleManagedRecordCopyWith(_TailscaleManagedRecord value, $Res Function(_TailscaleManagedRecord) _then) = __$TailscaleManagedRecordCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'profile-id') int profileId,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,@JsonKey(name: 'exit-node-name', includeIfNull: false) String? exitNodeName,@JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,@JsonKey(name: 'logged-out') bool loggedOut, bool attached, bool removing
});




}
/// @nodoc
class __$TailscaleManagedRecordCopyWithImpl<$Res>
    implements _$TailscaleManagedRecordCopyWith<$Res> {
  __$TailscaleManagedRecordCopyWithImpl(this._self, this._then);

  final _TailscaleManagedRecord _self;
  final $Res Function(_TailscaleManagedRecord) _then;

/// Create a copy of TailscaleManagedRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? profileId = null,Object? controlUrl = null,Object? exitNode = freezed,Object? exitNodeName = freezed,Object? acceptRoutes = freezed,Object? loggedOut = null,Object? attached = null,Object? removing = null,}) {
  return _then(_TailscaleManagedRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,exitNode: freezed == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String?,exitNodeName: freezed == exitNodeName ? _self.exitNodeName : exitNodeName // ignore: cast_nullable_to_non_nullable
as String?,acceptRoutes: freezed == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool?,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,attached: null == attached ? _self.attached : attached // ignore: cast_nullable_to_non_nullable
as bool,removing: null == removing ? _self.removing : removing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TailscaleManagedSetup {

 String get id; String get name;@JsonKey(name: 'control-url') String get controlUrl;@JsonKey(name: 'exit-node', includeIfNull: false) String? get exitNode;@JsonKey(name: 'accept-routes', includeIfNull: false) bool? get acceptRoutes;@JsonKey(name: 'logged-out') bool get loggedOut; bool get attached;
/// Create a copy of TailscaleManagedSetup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleManagedSetupCopyWith<TailscaleManagedSetup> get copyWith => _$TailscaleManagedSetupCopyWithImpl<TailscaleManagedSetup>(this as TailscaleManagedSetup, _$identity);

  /// Serializes this TailscaleManagedSetup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleManagedSetup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleManagedSetup&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl)&&(identical(other.exitNode, _this.exitNode) || other.exitNode == _this.exitNode)&&(identical(other.acceptRoutes, _this.acceptRoutes) || other.acceptRoutes == _this.acceptRoutes)&&(identical(other.loggedOut, _this.loggedOut) || other.loggedOut == _this.loggedOut)&&(identical(other.attached, _this.attached) || other.attached == _this.attached));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleManagedSetup;
  return Object.hash(runtimeType,_this.id,_this.name,_this.controlUrl,_this.exitNode,_this.acceptRoutes,_this.loggedOut,_this.attached);
}

@override
String toString() {
  final _this = this as TailscaleManagedSetup;
  return 'TailscaleManagedSetup(id: ${_this.id}, name: ${_this.name}, controlUrl: ${_this.controlUrl}, exitNode: ${_this.exitNode}, acceptRoutes: ${_this.acceptRoutes}, loggedOut: ${_this.loggedOut}, attached: ${_this.attached})';
}


}

/// @nodoc
abstract mixin class $TailscaleManagedSetupCopyWith<$Res>  {
  factory $TailscaleManagedSetupCopyWith(TailscaleManagedSetup value, $Res Function(TailscaleManagedSetup) _then) = _$TailscaleManagedSetupCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,@JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,@JsonKey(name: 'logged-out') bool loggedOut, bool attached
});




}
/// @nodoc
class _$TailscaleManagedSetupCopyWithImpl<$Res>
    implements $TailscaleManagedSetupCopyWith<$Res> {
  _$TailscaleManagedSetupCopyWithImpl(this._self, this._then);

  final TailscaleManagedSetup _self;
  final $Res Function(TailscaleManagedSetup) _then;

/// Create a copy of TailscaleManagedSetup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? controlUrl = null,Object? exitNode = freezed,Object? acceptRoutes = freezed,Object? loggedOut = null,Object? attached = null,}) {
  return _then(TailscaleManagedSetup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,exitNode: freezed == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String?,acceptRoutes: freezed == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool?,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,attached: null == attached ? _self.attached : attached // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleManagedSetup].
extension TailscaleManagedSetupPatterns on TailscaleManagedSetup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleManagedSetup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleManagedSetup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleManagedSetup value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleManagedSetup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleManagedSetup value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleManagedSetup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut,  bool attached)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleManagedSetup() when $default != null:
return $default(_that.id,_that.name,_that.controlUrl,_that.exitNode,_that.acceptRoutes,_that.loggedOut,_that.attached);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut,  bool attached)  $default,) {final _that = this;
switch (_that) {
case _TailscaleManagedSetup():
return $default(_that.id,_that.name,_that.controlUrl,_that.exitNode,_that.acceptRoutes,_that.loggedOut,_that.attached);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'exit-node', includeIfNull: false)  String? exitNode, @JsonKey(name: 'accept-routes', includeIfNull: false)  bool? acceptRoutes, @JsonKey(name: 'logged-out')  bool loggedOut,  bool attached)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleManagedSetup() when $default != null:
return $default(_that.id,_that.name,_that.controlUrl,_that.exitNode,_that.acceptRoutes,_that.loggedOut,_that.attached);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleManagedSetup implements TailscaleManagedSetup {
  const _TailscaleManagedSetup({required this.id, this.name = '', @JsonKey(name: 'control-url') this.controlUrl = '', @JsonKey(name: 'exit-node', includeIfNull: false) this.exitNode, @JsonKey(name: 'accept-routes', includeIfNull: false) this.acceptRoutes, @JsonKey(name: 'logged-out') this.loggedOut = false, this.attached = false});
  factory _TailscaleManagedSetup.fromJson(Map<String, dynamic> json) => _$TailscaleManagedSetupFromJson(json);

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'control-url') final  String controlUrl;
@override@JsonKey(name: 'exit-node', includeIfNull: false) final  String? exitNode;
@override@JsonKey(name: 'accept-routes', includeIfNull: false) final  bool? acceptRoutes;
@override@JsonKey(name: 'logged-out') final  bool loggedOut;
@override@JsonKey() final  bool attached;

/// Create a copy of TailscaleManagedSetup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleManagedSetupCopyWith<_TailscaleManagedSetup> get copyWith => __$TailscaleManagedSetupCopyWithImpl<_TailscaleManagedSetup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleManagedSetupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleManagedSetup&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl)&&(identical(other.exitNode, exitNode) || other.exitNode == exitNode)&&(identical(other.acceptRoutes, acceptRoutes) || other.acceptRoutes == acceptRoutes)&&(identical(other.loggedOut, loggedOut) || other.loggedOut == loggedOut)&&(identical(other.attached, attached) || other.attached == attached));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,controlUrl,exitNode,acceptRoutes,loggedOut,attached);
}

@override
String toString() {
    return 'TailscaleManagedSetup(id: $id, name: $name, controlUrl: $controlUrl, exitNode: $exitNode, acceptRoutes: $acceptRoutes, loggedOut: $loggedOut, attached: $attached)';
}


}

/// @nodoc
abstract mixin class _$TailscaleManagedSetupCopyWith<$Res> implements $TailscaleManagedSetupCopyWith<$Res> {
  factory _$TailscaleManagedSetupCopyWith(_TailscaleManagedSetup value, $Res Function(_TailscaleManagedSetup) _then) = __$TailscaleManagedSetupCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'exit-node', includeIfNull: false) String? exitNode,@JsonKey(name: 'accept-routes', includeIfNull: false) bool? acceptRoutes,@JsonKey(name: 'logged-out') bool loggedOut, bool attached
});




}
/// @nodoc
class __$TailscaleManagedSetupCopyWithImpl<$Res>
    implements _$TailscaleManagedSetupCopyWith<$Res> {
  __$TailscaleManagedSetupCopyWithImpl(this._self, this._then);

  final _TailscaleManagedSetup _self;
  final $Res Function(_TailscaleManagedSetup) _then;

/// Create a copy of TailscaleManagedSetup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? controlUrl = null,Object? exitNode = freezed,Object? acceptRoutes = freezed,Object? loggedOut = null,Object? attached = null,}) {
  return _then(_TailscaleManagedSetup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,exitNode: freezed == exitNode ? _self.exitNode : exitNode // ignore: cast_nullable_to_non_nullable
as String?,acceptRoutes: freezed == acceptRoutes ? _self.acceptRoutes : acceptRoutes // ignore: cast_nullable_to_non_nullable
as bool?,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,attached: null == attached ? _self.attached : attached // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TailscaleSetup {

@JsonKey(name: 'profile-id') int get profileId;@JsonKey(name: 'config-source') TailscaleSettingSource get configSource; List<TailscaleNodeSetup> get nodes;@JsonKey(name: 'legacy-migration', includeIfNull: false) TailscaleLegacyMigration? get legacyMigration; List<TailscaleManagedSetup> get managed;
/// Create a copy of TailscaleSetup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleSetupCopyWith<TailscaleSetup> get copyWith => _$TailscaleSetupCopyWithImpl<TailscaleSetup>(this as TailscaleSetup, _$identity);

  /// Serializes this TailscaleSetup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleSetup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleSetup&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&(identical(other.configSource, _this.configSource) || other.configSource == _this.configSource)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes)&&(identical(other.legacyMigration, _this.legacyMigration) || other.legacyMigration == _this.legacyMigration)&&const DeepCollectionEquality().equals(other.managed, _this.managed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleSetup;
  return Object.hash(runtimeType,_this.profileId,_this.configSource,const DeepCollectionEquality().hash(_this.nodes),_this.legacyMigration,const DeepCollectionEquality().hash(_this.managed));
}

@override
String toString() {
  final _this = this as TailscaleSetup;
  return 'TailscaleSetup(profileId: ${_this.profileId}, configSource: ${_this.configSource}, nodes: ${_this.nodes}, legacyMigration: ${_this.legacyMigration}, managed: ${_this.managed})';
}


}

/// @nodoc
abstract mixin class $TailscaleSetupCopyWith<$Res>  {
  factory $TailscaleSetupCopyWith(TailscaleSetup value, $Res Function(TailscaleSetup) _then) = _$TailscaleSetupCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId,@JsonKey(name: 'config-source') TailscaleSettingSource configSource, List<TailscaleNodeSetup> nodes,@JsonKey(name: 'legacy-migration', includeIfNull: false) TailscaleLegacyMigration? legacyMigration, List<TailscaleManagedSetup> managed
});


$TailscaleLegacyMigrationCopyWith<$Res>? get legacyMigration;

}
/// @nodoc
class _$TailscaleSetupCopyWithImpl<$Res>
    implements $TailscaleSetupCopyWith<$Res> {
  _$TailscaleSetupCopyWithImpl(this._self, this._then);

  final TailscaleSetup _self;
  final $Res Function(TailscaleSetup) _then;

/// Create a copy of TailscaleSetup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? configSource = null,Object? nodes = null,Object? legacyMigration = freezed,Object? managed = null,}) {
  return _then(TailscaleSetup(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,configSource: null == configSource ? _self.configSource : configSource // ignore: cast_nullable_to_non_nullable
as TailscaleSettingSource,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<TailscaleNodeSetup>,legacyMigration: freezed == legacyMigration ? _self.legacyMigration : legacyMigration // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyMigration?,managed: null == managed ? _self.managed : managed // ignore: cast_nullable_to_non_nullable
as List<TailscaleManagedSetup>,
  ));
}
/// Create a copy of TailscaleSetup
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleLegacyMigrationCopyWith<$Res>? get legacyMigration {
    if (_self.legacyMigration == null) {
    return null;
  }

  return $TailscaleLegacyMigrationCopyWith<$Res>(_self.legacyMigration!, (value) {
    return _then(_self.copyWith(legacyMigration: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleSetup].
extension TailscaleSetupPatterns on TailscaleSetup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleSetup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleSetup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleSetup value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleSetup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleSetup value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleSetup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId, @JsonKey(name: 'config-source')  TailscaleSettingSource configSource,  List<TailscaleNodeSetup> nodes, @JsonKey(name: 'legacy-migration', includeIfNull: false)  TailscaleLegacyMigration? legacyMigration,  List<TailscaleManagedSetup> managed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleSetup() when $default != null:
return $default(_that.profileId,_that.configSource,_that.nodes,_that.legacyMigration,_that.managed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId, @JsonKey(name: 'config-source')  TailscaleSettingSource configSource,  List<TailscaleNodeSetup> nodes, @JsonKey(name: 'legacy-migration', includeIfNull: false)  TailscaleLegacyMigration? legacyMigration,  List<TailscaleManagedSetup> managed)  $default,) {final _that = this;
switch (_that) {
case _TailscaleSetup():
return $default(_that.profileId,_that.configSource,_that.nodes,_that.legacyMigration,_that.managed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'profile-id')  int profileId, @JsonKey(name: 'config-source')  TailscaleSettingSource configSource,  List<TailscaleNodeSetup> nodes, @JsonKey(name: 'legacy-migration', includeIfNull: false)  TailscaleLegacyMigration? legacyMigration,  List<TailscaleManagedSetup> managed)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleSetup() when $default != null:
return $default(_that.profileId,_that.configSource,_that.nodes,_that.legacyMigration,_that.managed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleSetup implements TailscaleSetup {
  const _TailscaleSetup({@JsonKey(name: 'profile-id') required this.profileId, @JsonKey(name: 'config-source') required this.configSource,  List<TailscaleNodeSetup> nodes = const [], @JsonKey(name: 'legacy-migration', includeIfNull: false) this.legacyMigration,  List<TailscaleManagedSetup> managed = const []}): _nodes = nodes,_managed = managed;
  factory _TailscaleSetup.fromJson(Map<String, dynamic> json) => _$TailscaleSetupFromJson(json);

@override@JsonKey(name: 'profile-id') final  int profileId;
@override@JsonKey(name: 'config-source') final  TailscaleSettingSource configSource;
 final  List<TailscaleNodeSetup> _nodes;
@override@JsonKey() List<TailscaleNodeSetup> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}

@override@JsonKey(name: 'legacy-migration', includeIfNull: false) final  TailscaleLegacyMigration? legacyMigration;
 final  List<TailscaleManagedSetup> _managed;
@override@JsonKey() List<TailscaleManagedSetup> get managed {
  if (_managed is EqualUnmodifiableListView) return _managed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_managed);
}


/// Create a copy of TailscaleSetup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleSetupCopyWith<_TailscaleSetup> get copyWith => __$TailscaleSetupCopyWithImpl<_TailscaleSetup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleSetupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleSetup&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.configSource, configSource) || other.configSource == configSource)&&const DeepCollectionEquality().equals(other.nodes, _nodes)&&(identical(other.legacyMigration, legacyMigration) || other.legacyMigration == legacyMigration)&&const DeepCollectionEquality().equals(other.managed, _managed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,profileId,configSource,const DeepCollectionEquality().hash(_nodes),legacyMigration,const DeepCollectionEquality().hash(_managed));
}

@override
String toString() {
    return 'TailscaleSetup(profileId: $profileId, configSource: $configSource, nodes: $nodes, legacyMigration: $legacyMigration, managed: $managed)';
}


}

/// @nodoc
abstract mixin class _$TailscaleSetupCopyWith<$Res> implements $TailscaleSetupCopyWith<$Res> {
  factory _$TailscaleSetupCopyWith(_TailscaleSetup value, $Res Function(_TailscaleSetup) _then) = __$TailscaleSetupCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId,@JsonKey(name: 'config-source') TailscaleSettingSource configSource, List<TailscaleNodeSetup> nodes,@JsonKey(name: 'legacy-migration', includeIfNull: false) TailscaleLegacyMigration? legacyMigration, List<TailscaleManagedSetup> managed
});


@override $TailscaleLegacyMigrationCopyWith<$Res>? get legacyMigration;

}
/// @nodoc
class __$TailscaleSetupCopyWithImpl<$Res>
    implements _$TailscaleSetupCopyWith<$Res> {
  __$TailscaleSetupCopyWithImpl(this._self, this._then);

  final _TailscaleSetup _self;
  final $Res Function(_TailscaleSetup) _then;

/// Create a copy of TailscaleSetup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? configSource = null,Object? nodes = null,Object? legacyMigration = freezed,Object? managed = null,}) {
  return _then(_TailscaleSetup(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,configSource: null == configSource ? _self.configSource : configSource // ignore: cast_nullable_to_non_nullable
as TailscaleSettingSource,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<TailscaleNodeSetup>,legacyMigration: freezed == legacyMigration ? _self.legacyMigration : legacyMigration // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyMigration?,managed: null == managed ? _self._managed : managed // ignore: cast_nullable_to_non_nullable
as List<TailscaleManagedSetup>,
  ));
}

/// Create a copy of TailscaleSetup
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleLegacyMigrationCopyWith<$Res>? get legacyMigration {
    if (_self.legacyMigration == null) {
    return null;
  }

  return $TailscaleLegacyMigrationCopyWith<$Res>(_self.legacyMigration!, (value) {
    return _then(_self.copyWith(legacyMigration: value));
  });
}
}

/// @nodoc
mixin _$TailscaleSetPrefsResult {

 TailscaleSetPrefsOutcome get outcome; TailscalePrefs? get prefs; TailscaleError? get error;
/// Create a copy of TailscaleSetPrefsResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleSetPrefsResultCopyWith<TailscaleSetPrefsResult> get copyWith => _$TailscaleSetPrefsResultCopyWithImpl<TailscaleSetPrefsResult>(this as TailscaleSetPrefsResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TailscaleSetPrefsResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleSetPrefsResult&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.prefs, _this.prefs) || other.prefs == _this.prefs)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as TailscaleSetPrefsResult;
  return Object.hash(runtimeType,_this.outcome,_this.prefs,_this.error);
}

@override
String toString() {
  final _this = this as TailscaleSetPrefsResult;
  return 'TailscaleSetPrefsResult(outcome: ${_this.outcome}, prefs: ${_this.prefs}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $TailscaleSetPrefsResultCopyWith<$Res>  {
  factory $TailscaleSetPrefsResultCopyWith(TailscaleSetPrefsResult value, $Res Function(TailscaleSetPrefsResult) _then) = _$TailscaleSetPrefsResultCopyWithImpl;
@useResult
$Res call({
 TailscaleSetPrefsOutcome outcome, TailscalePrefs? prefs, TailscaleError? error
});


$TailscalePrefsCopyWith<$Res>? get prefs;$TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$TailscaleSetPrefsResultCopyWithImpl<$Res>
    implements $TailscaleSetPrefsResultCopyWith<$Res> {
  _$TailscaleSetPrefsResultCopyWithImpl(this._self, this._then);

  final TailscaleSetPrefsResult _self;
  final $Res Function(TailscaleSetPrefsResult) _then;

/// Create a copy of TailscaleSetPrefsResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? outcome = null,Object? prefs = freezed,Object? error = freezed,}) {
  return _then(TailscaleSetPrefsResult(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as TailscaleSetPrefsOutcome,prefs: freezed == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as TailscalePrefs?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}
/// Create a copy of TailscaleSetPrefsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscalePrefsCopyWith<$Res>? get prefs {
    if (_self.prefs == null) {
    return null;
  }

  return $TailscalePrefsCopyWith<$Res>(_self.prefs!, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}/// Create a copy of TailscaleSetPrefsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleSetPrefsResult].
extension TailscaleSetPrefsResultPatterns on TailscaleSetPrefsResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleSetPrefsResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleSetPrefsResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleSetPrefsResult value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleSetPrefsResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleSetPrefsResult value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleSetPrefsResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TailscaleSetPrefsOutcome outcome,  TailscalePrefs? prefs,  TailscaleError? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleSetPrefsResult() when $default != null:
return $default(_that.outcome,_that.prefs,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TailscaleSetPrefsOutcome outcome,  TailscalePrefs? prefs,  TailscaleError? error)  $default,) {final _that = this;
switch (_that) {
case _TailscaleSetPrefsResult():
return $default(_that.outcome,_that.prefs,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TailscaleSetPrefsOutcome outcome,  TailscalePrefs? prefs,  TailscaleError? error)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleSetPrefsResult() when $default != null:
return $default(_that.outcome,_that.prefs,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _TailscaleSetPrefsResult implements TailscaleSetPrefsResult {
  const _TailscaleSetPrefsResult({required this.outcome, this.prefs, this.error});
  

@override final  TailscaleSetPrefsOutcome outcome;
@override final  TailscalePrefs? prefs;
@override final  TailscaleError? error;

/// Create a copy of TailscaleSetPrefsResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleSetPrefsResultCopyWith<_TailscaleSetPrefsResult> get copyWith => __$TailscaleSetPrefsResultCopyWithImpl<_TailscaleSetPrefsResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleSetPrefsResult&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.prefs, prefs) || other.prefs == prefs)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,outcome,prefs,error);
}

@override
String toString() {
    return 'TailscaleSetPrefsResult(outcome: $outcome, prefs: $prefs, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TailscaleSetPrefsResultCopyWith<$Res> implements $TailscaleSetPrefsResultCopyWith<$Res> {
  factory _$TailscaleSetPrefsResultCopyWith(_TailscaleSetPrefsResult value, $Res Function(_TailscaleSetPrefsResult) _then) = __$TailscaleSetPrefsResultCopyWithImpl;
@override @useResult
$Res call({
 TailscaleSetPrefsOutcome outcome, TailscalePrefs? prefs, TailscaleError? error
});


@override $TailscalePrefsCopyWith<$Res>? get prefs;@override $TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class __$TailscaleSetPrefsResultCopyWithImpl<$Res>
    implements _$TailscaleSetPrefsResultCopyWith<$Res> {
  __$TailscaleSetPrefsResultCopyWithImpl(this._self, this._then);

  final _TailscaleSetPrefsResult _self;
  final $Res Function(_TailscaleSetPrefsResult) _then;

/// Create a copy of TailscaleSetPrefsResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? outcome = null,Object? prefs = freezed,Object? error = freezed,}) {
  return _then(_TailscaleSetPrefsResult(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as TailscaleSetPrefsOutcome,prefs: freezed == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as TailscalePrefs?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}

/// Create a copy of TailscaleSetPrefsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscalePrefsCopyWith<$Res>? get prefs {
    if (_self.prefs == null) {
    return null;
  }

  return $TailscalePrefsCopyWith<$Res>(_self.prefs!, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}/// Create a copy of TailscaleSetPrefsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

/// @nodoc
mixin _$TailscaleLegacyState {

 bool get offered; bool get migrating; TailscaleLegacyNotice get notice;/// The Core read the archive back unchanged after the last attempt.
 bool get archiveIntact;/// Where the last attempt stopped; null when no result came back.
 TailscaleMigrateStage? get stage;
/// Create a copy of TailscaleLegacyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleLegacyStateCopyWith<TailscaleLegacyState> get copyWith => _$TailscaleLegacyStateCopyWithImpl<TailscaleLegacyState>(this as TailscaleLegacyState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TailscaleLegacyState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleLegacyState&&(identical(other.offered, _this.offered) || other.offered == _this.offered)&&(identical(other.migrating, _this.migrating) || other.migrating == _this.migrating)&&(identical(other.notice, _this.notice) || other.notice == _this.notice)&&(identical(other.archiveIntact, _this.archiveIntact) || other.archiveIntact == _this.archiveIntact)&&(identical(other.stage, _this.stage) || other.stage == _this.stage));
}


@override
int get hashCode {
  final _this = this as TailscaleLegacyState;
  return Object.hash(runtimeType,_this.offered,_this.migrating,_this.notice,_this.archiveIntact,_this.stage);
}

@override
String toString() {
  final _this = this as TailscaleLegacyState;
  return 'TailscaleLegacyState(offered: ${_this.offered}, migrating: ${_this.migrating}, notice: ${_this.notice}, archiveIntact: ${_this.archiveIntact}, stage: ${_this.stage})';
}


}

/// @nodoc
abstract mixin class $TailscaleLegacyStateCopyWith<$Res>  {
  factory $TailscaleLegacyStateCopyWith(TailscaleLegacyState value, $Res Function(TailscaleLegacyState) _then) = _$TailscaleLegacyStateCopyWithImpl;
@useResult
$Res call({
 bool offered, bool migrating, TailscaleLegacyNotice notice, bool archiveIntact, TailscaleMigrateStage? stage
});




}
/// @nodoc
class _$TailscaleLegacyStateCopyWithImpl<$Res>
    implements $TailscaleLegacyStateCopyWith<$Res> {
  _$TailscaleLegacyStateCopyWithImpl(this._self, this._then);

  final TailscaleLegacyState _self;
  final $Res Function(TailscaleLegacyState) _then;

/// Create a copy of TailscaleLegacyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? offered = null,Object? migrating = null,Object? notice = null,Object? archiveIntact = null,Object? stage = freezed,}) {
  return _then(TailscaleLegacyState(
offered: null == offered ? _self.offered : offered // ignore: cast_nullable_to_non_nullable
as bool,migrating: null == migrating ? _self.migrating : migrating // ignore: cast_nullable_to_non_nullable
as bool,notice: null == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyNotice,archiveIntact: null == archiveIntact ? _self.archiveIntact : archiveIntact // ignore: cast_nullable_to_non_nullable
as bool,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as TailscaleMigrateStage?,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleLegacyState].
extension TailscaleLegacyStatePatterns on TailscaleLegacyState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleLegacyState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleLegacyState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleLegacyState value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleLegacyState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleLegacyState value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleLegacyState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool offered,  bool migrating,  TailscaleLegacyNotice notice,  bool archiveIntact,  TailscaleMigrateStage? stage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleLegacyState() when $default != null:
return $default(_that.offered,_that.migrating,_that.notice,_that.archiveIntact,_that.stage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool offered,  bool migrating,  TailscaleLegacyNotice notice,  bool archiveIntact,  TailscaleMigrateStage? stage)  $default,) {final _that = this;
switch (_that) {
case _TailscaleLegacyState():
return $default(_that.offered,_that.migrating,_that.notice,_that.archiveIntact,_that.stage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool offered,  bool migrating,  TailscaleLegacyNotice notice,  bool archiveIntact,  TailscaleMigrateStage? stage)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleLegacyState() when $default != null:
return $default(_that.offered,_that.migrating,_that.notice,_that.archiveIntact,_that.stage);case _:
  return null;

}
}

}

/// @nodoc


class _TailscaleLegacyState implements TailscaleLegacyState {
  const _TailscaleLegacyState({this.offered = false, this.migrating = false, this.notice = TailscaleLegacyNotice.none, this.archiveIntact = false, this.stage});
  

@override@JsonKey() final  bool offered;
@override@JsonKey() final  bool migrating;
@override@JsonKey() final  TailscaleLegacyNotice notice;
/// The Core read the archive back unchanged after the last attempt.
@override@JsonKey() final  bool archiveIntact;
/// Where the last attempt stopped; null when no result came back.
@override final  TailscaleMigrateStage? stage;

/// Create a copy of TailscaleLegacyState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleLegacyStateCopyWith<_TailscaleLegacyState> get copyWith => __$TailscaleLegacyStateCopyWithImpl<_TailscaleLegacyState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleLegacyState&&(identical(other.offered, offered) || other.offered == offered)&&(identical(other.migrating, migrating) || other.migrating == migrating)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.archiveIntact, archiveIntact) || other.archiveIntact == archiveIntact)&&(identical(other.stage, stage) || other.stage == stage));
}


@override
int get hashCode {
    return Object.hash(runtimeType,offered,migrating,notice,archiveIntact,stage);
}

@override
String toString() {
    return 'TailscaleLegacyState(offered: $offered, migrating: $migrating, notice: $notice, archiveIntact: $archiveIntact, stage: $stage)';
}


}

/// @nodoc
abstract mixin class _$TailscaleLegacyStateCopyWith<$Res> implements $TailscaleLegacyStateCopyWith<$Res> {
  factory _$TailscaleLegacyStateCopyWith(_TailscaleLegacyState value, $Res Function(_TailscaleLegacyState) _then) = __$TailscaleLegacyStateCopyWithImpl;
@override @useResult
$Res call({
 bool offered, bool migrating, TailscaleLegacyNotice notice, bool archiveIntact, TailscaleMigrateStage? stage
});




}
/// @nodoc
class __$TailscaleLegacyStateCopyWithImpl<$Res>
    implements _$TailscaleLegacyStateCopyWith<$Res> {
  __$TailscaleLegacyStateCopyWithImpl(this._self, this._then);

  final _TailscaleLegacyState _self;
  final $Res Function(_TailscaleLegacyState) _then;

/// Create a copy of TailscaleLegacyState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? offered = null,Object? migrating = null,Object? notice = null,Object? archiveIntact = null,Object? stage = freezed,}) {
  return _then(_TailscaleLegacyState(
offered: null == offered ? _self.offered : offered // ignore: cast_nullable_to_non_nullable
as bool,migrating: null == migrating ? _self.migrating : migrating // ignore: cast_nullable_to_non_nullable
as bool,notice: null == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as TailscaleLegacyNotice,archiveIntact: null == archiveIntact ? _self.archiveIntact : archiveIntact // ignore: cast_nullable_to_non_nullable
as bool,stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as TailscaleMigrateStage?,
  ));
}


}

/// @nodoc
mixin _$TailscalePanelNode {

/// The last read; it belongs to the node's instance of its generation.
 TailscaleStatus? get status;/// The latest read failed; [status] is then what an earlier one gave.
 bool get readFailed; bool get reading; bool get loggingIn; bool get starting;/// The panel's own start call failed for this generation.
 bool get startFailed; bool get restarting; bool get loggingOut;/// An action's result is not known; only a read settles it.
 bool get unconfirmed; TailscaleCardNotice? get notice; bool get applyingExit; bool get applyingRoutes; TailscaleSettingNotice? get exitNotice; TailscaleSettingNotice? get routesNotice;/// The generation the panel already started once, so a reopen does not
/// start it again.
 int? get prewarmed;
/// Create a copy of TailscalePanelNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscalePanelNodeCopyWith<TailscalePanelNode> get copyWith => _$TailscalePanelNodeCopyWithImpl<TailscalePanelNode>(this as TailscalePanelNode, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TailscalePanelNode;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscalePanelNode&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.readFailed, _this.readFailed) || other.readFailed == _this.readFailed)&&(identical(other.reading, _this.reading) || other.reading == _this.reading)&&(identical(other.loggingIn, _this.loggingIn) || other.loggingIn == _this.loggingIn)&&(identical(other.starting, _this.starting) || other.starting == _this.starting)&&(identical(other.startFailed, _this.startFailed) || other.startFailed == _this.startFailed)&&(identical(other.restarting, _this.restarting) || other.restarting == _this.restarting)&&(identical(other.loggingOut, _this.loggingOut) || other.loggingOut == _this.loggingOut)&&(identical(other.unconfirmed, _this.unconfirmed) || other.unconfirmed == _this.unconfirmed)&&(identical(other.notice, _this.notice) || other.notice == _this.notice)&&(identical(other.applyingExit, _this.applyingExit) || other.applyingExit == _this.applyingExit)&&(identical(other.applyingRoutes, _this.applyingRoutes) || other.applyingRoutes == _this.applyingRoutes)&&(identical(other.exitNotice, _this.exitNotice) || other.exitNotice == _this.exitNotice)&&(identical(other.routesNotice, _this.routesNotice) || other.routesNotice == _this.routesNotice)&&(identical(other.prewarmed, _this.prewarmed) || other.prewarmed == _this.prewarmed));
}


@override
int get hashCode {
  final _this = this as TailscalePanelNode;
  return Object.hash(runtimeType,_this.status,_this.readFailed,_this.reading,_this.loggingIn,_this.starting,_this.startFailed,_this.restarting,_this.loggingOut,_this.unconfirmed,_this.notice,_this.applyingExit,_this.applyingRoutes,_this.exitNotice,_this.routesNotice,_this.prewarmed);
}

@override
String toString() {
  final _this = this as TailscalePanelNode;
  return 'TailscalePanelNode(status: ${_this.status}, readFailed: ${_this.readFailed}, reading: ${_this.reading}, loggingIn: ${_this.loggingIn}, starting: ${_this.starting}, startFailed: ${_this.startFailed}, restarting: ${_this.restarting}, loggingOut: ${_this.loggingOut}, unconfirmed: ${_this.unconfirmed}, notice: ${_this.notice}, applyingExit: ${_this.applyingExit}, applyingRoutes: ${_this.applyingRoutes}, exitNotice: ${_this.exitNotice}, routesNotice: ${_this.routesNotice}, prewarmed: ${_this.prewarmed})';
}


}

/// @nodoc
abstract mixin class $TailscalePanelNodeCopyWith<$Res>  {
  factory $TailscalePanelNodeCopyWith(TailscalePanelNode value, $Res Function(TailscalePanelNode) _then) = _$TailscalePanelNodeCopyWithImpl;
@useResult
$Res call({
 TailscaleStatus? status, bool readFailed, bool reading, bool loggingIn, bool starting, bool startFailed, bool restarting, bool loggingOut, bool unconfirmed, TailscaleCardNotice? notice, bool applyingExit, bool applyingRoutes, TailscaleSettingNotice? exitNotice, TailscaleSettingNotice? routesNotice, int? prewarmed
});


$TailscaleStatusCopyWith<$Res>? get status;

}
/// @nodoc
class _$TailscalePanelNodeCopyWithImpl<$Res>
    implements $TailscalePanelNodeCopyWith<$Res> {
  _$TailscalePanelNodeCopyWithImpl(this._self, this._then);

  final TailscalePanelNode _self;
  final $Res Function(TailscalePanelNode) _then;

/// Create a copy of TailscalePanelNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = freezed,Object? readFailed = null,Object? reading = null,Object? loggingIn = null,Object? starting = null,Object? startFailed = null,Object? restarting = null,Object? loggingOut = null,Object? unconfirmed = null,Object? notice = freezed,Object? applyingExit = null,Object? applyingRoutes = null,Object? exitNotice = freezed,Object? routesNotice = freezed,Object? prewarmed = freezed,}) {
  return _then(TailscalePanelNode(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TailscaleStatus?,readFailed: null == readFailed ? _self.readFailed : readFailed // ignore: cast_nullable_to_non_nullable
as bool,reading: null == reading ? _self.reading : reading // ignore: cast_nullable_to_non_nullable
as bool,loggingIn: null == loggingIn ? _self.loggingIn : loggingIn // ignore: cast_nullable_to_non_nullable
as bool,starting: null == starting ? _self.starting : starting // ignore: cast_nullable_to_non_nullable
as bool,startFailed: null == startFailed ? _self.startFailed : startFailed // ignore: cast_nullable_to_non_nullable
as bool,restarting: null == restarting ? _self.restarting : restarting // ignore: cast_nullable_to_non_nullable
as bool,loggingOut: null == loggingOut ? _self.loggingOut : loggingOut // ignore: cast_nullable_to_non_nullable
as bool,unconfirmed: null == unconfirmed ? _self.unconfirmed : unconfirmed // ignore: cast_nullable_to_non_nullable
as bool,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as TailscaleCardNotice?,applyingExit: null == applyingExit ? _self.applyingExit : applyingExit // ignore: cast_nullable_to_non_nullable
as bool,applyingRoutes: null == applyingRoutes ? _self.applyingRoutes : applyingRoutes // ignore: cast_nullable_to_non_nullable
as bool,exitNotice: freezed == exitNotice ? _self.exitNotice : exitNotice // ignore: cast_nullable_to_non_nullable
as TailscaleSettingNotice?,routesNotice: freezed == routesNotice ? _self.routesNotice : routesNotice // ignore: cast_nullable_to_non_nullable
as TailscaleSettingNotice?,prewarmed: freezed == prewarmed ? _self.prewarmed : prewarmed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of TailscalePanelNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleStatusCopyWith<$Res>? get status {
    if (_self.status == null) {
    return null;
  }

  return $TailscaleStatusCopyWith<$Res>(_self.status!, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscalePanelNode].
extension TailscalePanelNodePatterns on TailscalePanelNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscalePanelNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscalePanelNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscalePanelNode value)  $default,){
final _that = this;
switch (_that) {
case _TailscalePanelNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscalePanelNode value)?  $default,){
final _that = this;
switch (_that) {
case _TailscalePanelNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TailscaleStatus? status,  bool readFailed,  bool reading,  bool loggingIn,  bool starting,  bool startFailed,  bool restarting,  bool loggingOut,  bool unconfirmed,  TailscaleCardNotice? notice,  bool applyingExit,  bool applyingRoutes,  TailscaleSettingNotice? exitNotice,  TailscaleSettingNotice? routesNotice,  int? prewarmed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscalePanelNode() when $default != null:
return $default(_that.status,_that.readFailed,_that.reading,_that.loggingIn,_that.starting,_that.startFailed,_that.restarting,_that.loggingOut,_that.unconfirmed,_that.notice,_that.applyingExit,_that.applyingRoutes,_that.exitNotice,_that.routesNotice,_that.prewarmed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TailscaleStatus? status,  bool readFailed,  bool reading,  bool loggingIn,  bool starting,  bool startFailed,  bool restarting,  bool loggingOut,  bool unconfirmed,  TailscaleCardNotice? notice,  bool applyingExit,  bool applyingRoutes,  TailscaleSettingNotice? exitNotice,  TailscaleSettingNotice? routesNotice,  int? prewarmed)  $default,) {final _that = this;
switch (_that) {
case _TailscalePanelNode():
return $default(_that.status,_that.readFailed,_that.reading,_that.loggingIn,_that.starting,_that.startFailed,_that.restarting,_that.loggingOut,_that.unconfirmed,_that.notice,_that.applyingExit,_that.applyingRoutes,_that.exitNotice,_that.routesNotice,_that.prewarmed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TailscaleStatus? status,  bool readFailed,  bool reading,  bool loggingIn,  bool starting,  bool startFailed,  bool restarting,  bool loggingOut,  bool unconfirmed,  TailscaleCardNotice? notice,  bool applyingExit,  bool applyingRoutes,  TailscaleSettingNotice? exitNotice,  TailscaleSettingNotice? routesNotice,  int? prewarmed)?  $default,) {final _that = this;
switch (_that) {
case _TailscalePanelNode() when $default != null:
return $default(_that.status,_that.readFailed,_that.reading,_that.loggingIn,_that.starting,_that.startFailed,_that.restarting,_that.loggingOut,_that.unconfirmed,_that.notice,_that.applyingExit,_that.applyingRoutes,_that.exitNotice,_that.routesNotice,_that.prewarmed);case _:
  return null;

}
}

}

/// @nodoc


class _TailscalePanelNode implements TailscalePanelNode {
  const _TailscalePanelNode({this.status, this.readFailed = false, this.reading = false, this.loggingIn = false, this.starting = false, this.startFailed = false, this.restarting = false, this.loggingOut = false, this.unconfirmed = false, this.notice, this.applyingExit = false, this.applyingRoutes = false, this.exitNotice, this.routesNotice, this.prewarmed});
  

/// The last read; it belongs to the node's instance of its generation.
@override final  TailscaleStatus? status;
/// The latest read failed; [status] is then what an earlier one gave.
@override@JsonKey() final  bool readFailed;
@override@JsonKey() final  bool reading;
@override@JsonKey() final  bool loggingIn;
@override@JsonKey() final  bool starting;
/// The panel's own start call failed for this generation.
@override@JsonKey() final  bool startFailed;
@override@JsonKey() final  bool restarting;
@override@JsonKey() final  bool loggingOut;
/// An action's result is not known; only a read settles it.
@override@JsonKey() final  bool unconfirmed;
@override final  TailscaleCardNotice? notice;
@override@JsonKey() final  bool applyingExit;
@override@JsonKey() final  bool applyingRoutes;
@override final  TailscaleSettingNotice? exitNotice;
@override final  TailscaleSettingNotice? routesNotice;
/// The generation the panel already started once, so a reopen does not
/// start it again.
@override final  int? prewarmed;

/// Create a copy of TailscalePanelNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscalePanelNodeCopyWith<_TailscalePanelNode> get copyWith => __$TailscalePanelNodeCopyWithImpl<_TailscalePanelNode>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscalePanelNode&&(identical(other.status, status) || other.status == status)&&(identical(other.readFailed, readFailed) || other.readFailed == readFailed)&&(identical(other.reading, reading) || other.reading == reading)&&(identical(other.loggingIn, loggingIn) || other.loggingIn == loggingIn)&&(identical(other.starting, starting) || other.starting == starting)&&(identical(other.startFailed, startFailed) || other.startFailed == startFailed)&&(identical(other.restarting, restarting) || other.restarting == restarting)&&(identical(other.loggingOut, loggingOut) || other.loggingOut == loggingOut)&&(identical(other.unconfirmed, unconfirmed) || other.unconfirmed == unconfirmed)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.applyingExit, applyingExit) || other.applyingExit == applyingExit)&&(identical(other.applyingRoutes, applyingRoutes) || other.applyingRoutes == applyingRoutes)&&(identical(other.exitNotice, exitNotice) || other.exitNotice == exitNotice)&&(identical(other.routesNotice, routesNotice) || other.routesNotice == routesNotice)&&(identical(other.prewarmed, prewarmed) || other.prewarmed == prewarmed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,readFailed,reading,loggingIn,starting,startFailed,restarting,loggingOut,unconfirmed,notice,applyingExit,applyingRoutes,exitNotice,routesNotice,prewarmed);
}

@override
String toString() {
    return 'TailscalePanelNode(status: $status, readFailed: $readFailed, reading: $reading, loggingIn: $loggingIn, starting: $starting, startFailed: $startFailed, restarting: $restarting, loggingOut: $loggingOut, unconfirmed: $unconfirmed, notice: $notice, applyingExit: $applyingExit, applyingRoutes: $applyingRoutes, exitNotice: $exitNotice, routesNotice: $routesNotice, prewarmed: $prewarmed)';
}


}

/// @nodoc
abstract mixin class _$TailscalePanelNodeCopyWith<$Res> implements $TailscalePanelNodeCopyWith<$Res> {
  factory _$TailscalePanelNodeCopyWith(_TailscalePanelNode value, $Res Function(_TailscalePanelNode) _then) = __$TailscalePanelNodeCopyWithImpl;
@override @useResult
$Res call({
 TailscaleStatus? status, bool readFailed, bool reading, bool loggingIn, bool starting, bool startFailed, bool restarting, bool loggingOut, bool unconfirmed, TailscaleCardNotice? notice, bool applyingExit, bool applyingRoutes, TailscaleSettingNotice? exitNotice, TailscaleSettingNotice? routesNotice, int? prewarmed
});


@override $TailscaleStatusCopyWith<$Res>? get status;

}
/// @nodoc
class __$TailscalePanelNodeCopyWithImpl<$Res>
    implements _$TailscalePanelNodeCopyWith<$Res> {
  __$TailscalePanelNodeCopyWithImpl(this._self, this._then);

  final _TailscalePanelNode _self;
  final $Res Function(_TailscalePanelNode) _then;

/// Create a copy of TailscalePanelNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = freezed,Object? readFailed = null,Object? reading = null,Object? loggingIn = null,Object? starting = null,Object? startFailed = null,Object? restarting = null,Object? loggingOut = null,Object? unconfirmed = null,Object? notice = freezed,Object? applyingExit = null,Object? applyingRoutes = null,Object? exitNotice = freezed,Object? routesNotice = freezed,Object? prewarmed = freezed,}) {
  return _then(_TailscalePanelNode(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TailscaleStatus?,readFailed: null == readFailed ? _self.readFailed : readFailed // ignore: cast_nullable_to_non_nullable
as bool,reading: null == reading ? _self.reading : reading // ignore: cast_nullable_to_non_nullable
as bool,loggingIn: null == loggingIn ? _self.loggingIn : loggingIn // ignore: cast_nullable_to_non_nullable
as bool,starting: null == starting ? _self.starting : starting // ignore: cast_nullable_to_non_nullable
as bool,startFailed: null == startFailed ? _self.startFailed : startFailed // ignore: cast_nullable_to_non_nullable
as bool,restarting: null == restarting ? _self.restarting : restarting // ignore: cast_nullable_to_non_nullable
as bool,loggingOut: null == loggingOut ? _self.loggingOut : loggingOut // ignore: cast_nullable_to_non_nullable
as bool,unconfirmed: null == unconfirmed ? _self.unconfirmed : unconfirmed // ignore: cast_nullable_to_non_nullable
as bool,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as TailscaleCardNotice?,applyingExit: null == applyingExit ? _self.applyingExit : applyingExit // ignore: cast_nullable_to_non_nullable
as bool,applyingRoutes: null == applyingRoutes ? _self.applyingRoutes : applyingRoutes // ignore: cast_nullable_to_non_nullable
as bool,exitNotice: freezed == exitNotice ? _self.exitNotice : exitNotice // ignore: cast_nullable_to_non_nullable
as TailscaleSettingNotice?,routesNotice: freezed == routesNotice ? _self.routesNotice : routesNotice // ignore: cast_nullable_to_non_nullable
as TailscaleSettingNotice?,prewarmed: freezed == prewarmed ? _self.prewarmed : prewarmed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of TailscalePanelNode
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleStatusCopyWith<$Res>? get status {
    if (_self.status == null) {
    return null;
  }

  return $TailscaleStatusCopyWith<$Res>(_self.status!, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}


/// @nodoc
mixin _$TailscaleRouteTarget {

 String get kind; String get value;
/// Create a copy of TailscaleRouteTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleRouteTargetCopyWith<TailscaleRouteTarget> get copyWith => _$TailscaleRouteTargetCopyWithImpl<TailscaleRouteTarget>(this as TailscaleRouteTarget, _$identity);

  /// Serializes this TailscaleRouteTarget to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleRouteTarget;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleRouteTarget&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.value, _this.value) || other.value == _this.value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleRouteTarget;
  return Object.hash(runtimeType,_this.kind,_this.value);
}

@override
String toString() {
  final _this = this as TailscaleRouteTarget;
  return 'TailscaleRouteTarget(kind: ${_this.kind}, value: ${_this.value})';
}


}

/// @nodoc
abstract mixin class $TailscaleRouteTargetCopyWith<$Res>  {
  factory $TailscaleRouteTargetCopyWith(TailscaleRouteTarget value, $Res Function(TailscaleRouteTarget) _then) = _$TailscaleRouteTargetCopyWithImpl;
@useResult
$Res call({
 String kind, String value
});




}
/// @nodoc
class _$TailscaleRouteTargetCopyWithImpl<$Res>
    implements $TailscaleRouteTargetCopyWith<$Res> {
  _$TailscaleRouteTargetCopyWithImpl(this._self, this._then);

  final TailscaleRouteTarget _self;
  final $Res Function(TailscaleRouteTarget) _then;

/// Create a copy of TailscaleRouteTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? value = null,}) {
  return _then(TailscaleRouteTarget(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleRouteTarget].
extension TailscaleRouteTargetPatterns on TailscaleRouteTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleRouteTarget value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleRouteTarget() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleRouteTarget value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteTarget():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleRouteTarget value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteTarget() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleRouteTarget() when $default != null:
return $default(_that.kind,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String value)  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteTarget():
return $default(_that.kind,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String value)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteTarget() when $default != null:
return $default(_that.kind,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleRouteTarget implements TailscaleRouteTarget {
  const _TailscaleRouteTarget({required this.kind, required this.value});
  factory _TailscaleRouteTarget.fromJson(Map<String, dynamic> json) => _$TailscaleRouteTargetFromJson(json);

@override final  String kind;
@override final  String value;

/// Create a copy of TailscaleRouteTarget
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleRouteTargetCopyWith<_TailscaleRouteTarget> get copyWith => __$TailscaleRouteTargetCopyWithImpl<_TailscaleRouteTarget>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleRouteTargetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleRouteTarget&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,value);
}

@override
String toString() {
    return 'TailscaleRouteTarget(kind: $kind, value: $value)';
}


}

/// @nodoc
abstract mixin class _$TailscaleRouteTargetCopyWith<$Res> implements $TailscaleRouteTargetCopyWith<$Res> {
  factory _$TailscaleRouteTargetCopyWith(_TailscaleRouteTarget value, $Res Function(_TailscaleRouteTarget) _then) = __$TailscaleRouteTargetCopyWithImpl;
@override @useResult
$Res call({
 String kind, String value
});




}
/// @nodoc
class __$TailscaleRouteTargetCopyWithImpl<$Res>
    implements _$TailscaleRouteTargetCopyWith<$Res> {
  __$TailscaleRouteTargetCopyWithImpl(this._self, this._then);

  final _TailscaleRouteTarget _self;
  final $Res Function(_TailscaleRouteTarget) _then;

/// Create a copy of TailscaleRouteTarget
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? value = null,}) {
  return _then(_TailscaleRouteTarget(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TailscaleRouteOwner {

 String get kind; String get id;
/// Create a copy of TailscaleRouteOwner
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleRouteOwnerCopyWith<TailscaleRouteOwner> get copyWith => _$TailscaleRouteOwnerCopyWithImpl<TailscaleRouteOwner>(this as TailscaleRouteOwner, _$identity);

  /// Serializes this TailscaleRouteOwner to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleRouteOwner;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleRouteOwner&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.id, _this.id) || other.id == _this.id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleRouteOwner;
  return Object.hash(runtimeType,_this.kind,_this.id);
}

@override
String toString() {
  final _this = this as TailscaleRouteOwner;
  return 'TailscaleRouteOwner(kind: ${_this.kind}, id: ${_this.id})';
}


}

/// @nodoc
abstract mixin class $TailscaleRouteOwnerCopyWith<$Res>  {
  factory $TailscaleRouteOwnerCopyWith(TailscaleRouteOwner value, $Res Function(TailscaleRouteOwner) _then) = _$TailscaleRouteOwnerCopyWithImpl;
@useResult
$Res call({
 String kind, String id
});




}
/// @nodoc
class _$TailscaleRouteOwnerCopyWithImpl<$Res>
    implements $TailscaleRouteOwnerCopyWith<$Res> {
  _$TailscaleRouteOwnerCopyWithImpl(this._self, this._then);

  final TailscaleRouteOwner _self;
  final $Res Function(TailscaleRouteOwner) _then;

/// Create a copy of TailscaleRouteOwner
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? id = null,}) {
  return _then(TailscaleRouteOwner(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleRouteOwner].
extension TailscaleRouteOwnerPatterns on TailscaleRouteOwner {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleRouteOwner value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleRouteOwner() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleRouteOwner value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteOwner():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleRouteOwner value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteOwner() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleRouteOwner() when $default != null:
return $default(_that.kind,_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String id)  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteOwner():
return $default(_that.kind,_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String id)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteOwner() when $default != null:
return $default(_that.kind,_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleRouteOwner implements TailscaleRouteOwner {
  const _TailscaleRouteOwner({required this.kind, required this.id});
  factory _TailscaleRouteOwner.fromJson(Map<String, dynamic> json) => _$TailscaleRouteOwnerFromJson(json);

@override final  String kind;
@override final  String id;

/// Create a copy of TailscaleRouteOwner
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleRouteOwnerCopyWith<_TailscaleRouteOwner> get copyWith => __$TailscaleRouteOwnerCopyWithImpl<_TailscaleRouteOwner>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleRouteOwnerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleRouteOwner&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,id);
}

@override
String toString() {
    return 'TailscaleRouteOwner(kind: $kind, id: $id)';
}


}

/// @nodoc
abstract mixin class _$TailscaleRouteOwnerCopyWith<$Res> implements $TailscaleRouteOwnerCopyWith<$Res> {
  factory _$TailscaleRouteOwnerCopyWith(_TailscaleRouteOwner value, $Res Function(_TailscaleRouteOwner) _then) = __$TailscaleRouteOwnerCopyWithImpl;
@override @useResult
$Res call({
 String kind, String id
});




}
/// @nodoc
class __$TailscaleRouteOwnerCopyWithImpl<$Res>
    implements _$TailscaleRouteOwnerCopyWith<$Res> {
  __$TailscaleRouteOwnerCopyWithImpl(this._self, this._then);

  final _TailscaleRouteOwner _self;
  final $Res Function(_TailscaleRouteOwner) _then;

/// Create a copy of TailscaleRouteOwner
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? id = null,}) {
  return _then(_TailscaleRouteOwner(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TailscaleRouteIdentity {

@JsonKey(name: 'user-id') String get userId; String get tailnet;@JsonKey(name: 'control-url') String get controlUrl;@JsonKey(name: 'login-name') String get loginName;
/// Create a copy of TailscaleRouteIdentity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleRouteIdentityCopyWith<TailscaleRouteIdentity> get copyWith => _$TailscaleRouteIdentityCopyWithImpl<TailscaleRouteIdentity>(this as TailscaleRouteIdentity, _$identity);

  /// Serializes this TailscaleRouteIdentity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleRouteIdentity;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleRouteIdentity&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.tailnet, _this.tailnet) || other.tailnet == _this.tailnet)&&(identical(other.controlUrl, _this.controlUrl) || other.controlUrl == _this.controlUrl)&&(identical(other.loginName, _this.loginName) || other.loginName == _this.loginName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleRouteIdentity;
  return Object.hash(runtimeType,_this.userId,_this.tailnet,_this.controlUrl,_this.loginName);
}

@override
String toString() {
  final _this = this as TailscaleRouteIdentity;
  return 'TailscaleRouteIdentity(userId: ${_this.userId}, tailnet: ${_this.tailnet}, controlUrl: ${_this.controlUrl}, loginName: ${_this.loginName})';
}


}

/// @nodoc
abstract mixin class $TailscaleRouteIdentityCopyWith<$Res>  {
  factory $TailscaleRouteIdentityCopyWith(TailscaleRouteIdentity value, $Res Function(TailscaleRouteIdentity) _then) = _$TailscaleRouteIdentityCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user-id') String userId, String tailnet,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'login-name') String loginName
});




}
/// @nodoc
class _$TailscaleRouteIdentityCopyWithImpl<$Res>
    implements $TailscaleRouteIdentityCopyWith<$Res> {
  _$TailscaleRouteIdentityCopyWithImpl(this._self, this._then);

  final TailscaleRouteIdentity _self;
  final $Res Function(TailscaleRouteIdentity) _then;

/// Create a copy of TailscaleRouteIdentity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? tailnet = null,Object? controlUrl = null,Object? loginName = null,}) {
  return _then(TailscaleRouteIdentity(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,tailnet: null == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleRouteIdentity].
extension TailscaleRouteIdentityPatterns on TailscaleRouteIdentity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleRouteIdentity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleRouteIdentity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleRouteIdentity value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteIdentity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleRouteIdentity value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteIdentity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user-id')  String userId,  String tailnet, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'login-name')  String loginName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleRouteIdentity() when $default != null:
return $default(_that.userId,_that.tailnet,_that.controlUrl,_that.loginName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user-id')  String userId,  String tailnet, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'login-name')  String loginName)  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteIdentity():
return $default(_that.userId,_that.tailnet,_that.controlUrl,_that.loginName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user-id')  String userId,  String tailnet, @JsonKey(name: 'control-url')  String controlUrl, @JsonKey(name: 'login-name')  String loginName)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteIdentity() when $default != null:
return $default(_that.userId,_that.tailnet,_that.controlUrl,_that.loginName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleRouteIdentity implements TailscaleRouteIdentity {
  const _TailscaleRouteIdentity({@JsonKey(name: 'user-id') this.userId = '', this.tailnet = '', @JsonKey(name: 'control-url') this.controlUrl = '', @JsonKey(name: 'login-name') this.loginName = ''});
  factory _TailscaleRouteIdentity.fromJson(Map<String, dynamic> json) => _$TailscaleRouteIdentityFromJson(json);

@override@JsonKey(name: 'user-id') final  String userId;
@override@JsonKey() final  String tailnet;
@override@JsonKey(name: 'control-url') final  String controlUrl;
@override@JsonKey(name: 'login-name') final  String loginName;

/// Create a copy of TailscaleRouteIdentity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleRouteIdentityCopyWith<_TailscaleRouteIdentity> get copyWith => __$TailscaleRouteIdentityCopyWithImpl<_TailscaleRouteIdentity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleRouteIdentityToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleRouteIdentity&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.tailnet, tailnet) || other.tailnet == tailnet)&&(identical(other.controlUrl, controlUrl) || other.controlUrl == controlUrl)&&(identical(other.loginName, loginName) || other.loginName == loginName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,userId,tailnet,controlUrl,loginName);
}

@override
String toString() {
    return 'TailscaleRouteIdentity(userId: $userId, tailnet: $tailnet, controlUrl: $controlUrl, loginName: $loginName)';
}


}

/// @nodoc
abstract mixin class _$TailscaleRouteIdentityCopyWith<$Res> implements $TailscaleRouteIdentityCopyWith<$Res> {
  factory _$TailscaleRouteIdentityCopyWith(_TailscaleRouteIdentity value, $Res Function(_TailscaleRouteIdentity) _then) = __$TailscaleRouteIdentityCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user-id') String userId, String tailnet,@JsonKey(name: 'control-url') String controlUrl,@JsonKey(name: 'login-name') String loginName
});




}
/// @nodoc
class __$TailscaleRouteIdentityCopyWithImpl<$Res>
    implements _$TailscaleRouteIdentityCopyWith<$Res> {
  __$TailscaleRouteIdentityCopyWithImpl(this._self, this._then);

  final _TailscaleRouteIdentity _self;
  final $Res Function(_TailscaleRouteIdentity) _then;

/// Create a copy of TailscaleRouteIdentity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? tailnet = null,Object? controlUrl = null,Object? loginName = null,}) {
  return _then(_TailscaleRouteIdentity(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,tailnet: null == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as String,controlUrl: null == controlUrl ? _self.controlUrl : controlUrl // ignore: cast_nullable_to_non_nullable
as String,loginName: null == loginName ? _self.loginName : loginName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TailscaleRouteCandidate {

 TailscaleRouteOwner get owner; String get device; String get label; String get tailnet; String get rule; bool get removed;
/// Create a copy of TailscaleRouteCandidate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleRouteCandidateCopyWith<TailscaleRouteCandidate> get copyWith => _$TailscaleRouteCandidateCopyWithImpl<TailscaleRouteCandidate>(this as TailscaleRouteCandidate, _$identity);

  /// Serializes this TailscaleRouteCandidate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleRouteCandidate;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleRouteCandidate&&(identical(other.owner, _this.owner) || other.owner == _this.owner)&&(identical(other.device, _this.device) || other.device == _this.device)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.tailnet, _this.tailnet) || other.tailnet == _this.tailnet)&&(identical(other.rule, _this.rule) || other.rule == _this.rule)&&(identical(other.removed, _this.removed) || other.removed == _this.removed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleRouteCandidate;
  return Object.hash(runtimeType,_this.owner,_this.device,_this.label,_this.tailnet,_this.rule,_this.removed);
}

@override
String toString() {
  final _this = this as TailscaleRouteCandidate;
  return 'TailscaleRouteCandidate(owner: ${_this.owner}, device: ${_this.device}, label: ${_this.label}, tailnet: ${_this.tailnet}, rule: ${_this.rule}, removed: ${_this.removed})';
}


}

/// @nodoc
abstract mixin class $TailscaleRouteCandidateCopyWith<$Res>  {
  factory $TailscaleRouteCandidateCopyWith(TailscaleRouteCandidate value, $Res Function(TailscaleRouteCandidate) _then) = _$TailscaleRouteCandidateCopyWithImpl;
@useResult
$Res call({
 TailscaleRouteOwner owner, String device, String label, String tailnet, String rule, bool removed
});


$TailscaleRouteOwnerCopyWith<$Res> get owner;

}
/// @nodoc
class _$TailscaleRouteCandidateCopyWithImpl<$Res>
    implements $TailscaleRouteCandidateCopyWith<$Res> {
  _$TailscaleRouteCandidateCopyWithImpl(this._self, this._then);

  final TailscaleRouteCandidate _self;
  final $Res Function(TailscaleRouteCandidate) _then;

/// Create a copy of TailscaleRouteCandidate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? owner = null,Object? device = null,Object? label = null,Object? tailnet = null,Object? rule = null,Object? removed = null,}) {
  return _then(TailscaleRouteCandidate(
owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as TailscaleRouteOwner,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,tailnet: null == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as String,rule: null == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as String,removed: null == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of TailscaleRouteCandidate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteOwnerCopyWith<$Res> get owner {
  
  return $TailscaleRouteOwnerCopyWith<$Res>(_self.owner, (value) {
    return _then(_self.copyWith(owner: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleRouteCandidate].
extension TailscaleRouteCandidatePatterns on TailscaleRouteCandidate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleRouteCandidate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleRouteCandidate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleRouteCandidate value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteCandidate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleRouteCandidate value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteCandidate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TailscaleRouteOwner owner,  String device,  String label,  String tailnet,  String rule,  bool removed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleRouteCandidate() when $default != null:
return $default(_that.owner,_that.device,_that.label,_that.tailnet,_that.rule,_that.removed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TailscaleRouteOwner owner,  String device,  String label,  String tailnet,  String rule,  bool removed)  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteCandidate():
return $default(_that.owner,_that.device,_that.label,_that.tailnet,_that.rule,_that.removed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TailscaleRouteOwner owner,  String device,  String label,  String tailnet,  String rule,  bool removed)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteCandidate() when $default != null:
return $default(_that.owner,_that.device,_that.label,_that.tailnet,_that.rule,_that.removed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleRouteCandidate implements TailscaleRouteCandidate {
  const _TailscaleRouteCandidate({required this.owner, this.device = '', this.label = '', this.tailnet = '', this.rule = '', this.removed = false});
  factory _TailscaleRouteCandidate.fromJson(Map<String, dynamic> json) => _$TailscaleRouteCandidateFromJson(json);

@override final  TailscaleRouteOwner owner;
@override@JsonKey() final  String device;
@override@JsonKey() final  String label;
@override@JsonKey() final  String tailnet;
@override@JsonKey() final  String rule;
@override@JsonKey() final  bool removed;

/// Create a copy of TailscaleRouteCandidate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleRouteCandidateCopyWith<_TailscaleRouteCandidate> get copyWith => __$TailscaleRouteCandidateCopyWithImpl<_TailscaleRouteCandidate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleRouteCandidateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleRouteCandidate&&(identical(other.owner, owner) || other.owner == owner)&&(identical(other.device, device) || other.device == device)&&(identical(other.label, label) || other.label == label)&&(identical(other.tailnet, tailnet) || other.tailnet == tailnet)&&(identical(other.rule, rule) || other.rule == rule)&&(identical(other.removed, removed) || other.removed == removed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,owner,device,label,tailnet,rule,removed);
}

@override
String toString() {
    return 'TailscaleRouteCandidate(owner: $owner, device: $device, label: $label, tailnet: $tailnet, rule: $rule, removed: $removed)';
}


}

/// @nodoc
abstract mixin class _$TailscaleRouteCandidateCopyWith<$Res> implements $TailscaleRouteCandidateCopyWith<$Res> {
  factory _$TailscaleRouteCandidateCopyWith(_TailscaleRouteCandidate value, $Res Function(_TailscaleRouteCandidate) _then) = __$TailscaleRouteCandidateCopyWithImpl;
@override @useResult
$Res call({
 TailscaleRouteOwner owner, String device, String label, String tailnet, String rule, bool removed
});


@override $TailscaleRouteOwnerCopyWith<$Res> get owner;

}
/// @nodoc
class __$TailscaleRouteCandidateCopyWithImpl<$Res>
    implements _$TailscaleRouteCandidateCopyWith<$Res> {
  __$TailscaleRouteCandidateCopyWithImpl(this._self, this._then);

  final _TailscaleRouteCandidate _self;
  final $Res Function(_TailscaleRouteCandidate) _then;

/// Create a copy of TailscaleRouteCandidate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? owner = null,Object? device = null,Object? label = null,Object? tailnet = null,Object? rule = null,Object? removed = null,}) {
  return _then(_TailscaleRouteCandidate(
owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as TailscaleRouteOwner,device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,tailnet: null == tailnet ? _self.tailnet : tailnet // ignore: cast_nullable_to_non_nullable
as String,rule: null == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as String,removed: null == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of TailscaleRouteCandidate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteOwnerCopyWith<$Res> get owner {
  
  return $TailscaleRouteOwnerCopyWith<$Res>(_self.owner, (value) {
    return _then(_self.copyWith(owner: value));
  });
}
}


/// @nodoc
mixin _$TailscaleRouteTargetReport {

 TailscaleRouteTarget get target;@JsonKey(unknownEnumValue: TailscaleRouteState.unconfirmed) TailscaleRouteState get state; TailscaleRouteOwner? get owner; List<TailscaleRouteCandidate> get candidates;
/// Create a copy of TailscaleRouteTargetReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleRouteTargetReportCopyWith<TailscaleRouteTargetReport> get copyWith => _$TailscaleRouteTargetReportCopyWithImpl<TailscaleRouteTargetReport>(this as TailscaleRouteTargetReport, _$identity);

  /// Serializes this TailscaleRouteTargetReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleRouteTargetReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleRouteTargetReport&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.owner, _this.owner) || other.owner == _this.owner)&&const DeepCollectionEquality().equals(other.candidates, _this.candidates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleRouteTargetReport;
  return Object.hash(runtimeType,_this.target,_this.state,_this.owner,const DeepCollectionEquality().hash(_this.candidates));
}

@override
String toString() {
  final _this = this as TailscaleRouteTargetReport;
  return 'TailscaleRouteTargetReport(target: ${_this.target}, state: ${_this.state}, owner: ${_this.owner}, candidates: ${_this.candidates})';
}


}

/// @nodoc
abstract mixin class $TailscaleRouteTargetReportCopyWith<$Res>  {
  factory $TailscaleRouteTargetReportCopyWith(TailscaleRouteTargetReport value, $Res Function(TailscaleRouteTargetReport) _then) = _$TailscaleRouteTargetReportCopyWithImpl;
@useResult
$Res call({
 TailscaleRouteTarget target,@JsonKey(unknownEnumValue: TailscaleRouteState.unconfirmed) TailscaleRouteState state, TailscaleRouteOwner? owner, List<TailscaleRouteCandidate> candidates
});


$TailscaleRouteTargetCopyWith<$Res> get target;$TailscaleRouteOwnerCopyWith<$Res>? get owner;

}
/// @nodoc
class _$TailscaleRouteTargetReportCopyWithImpl<$Res>
    implements $TailscaleRouteTargetReportCopyWith<$Res> {
  _$TailscaleRouteTargetReportCopyWithImpl(this._self, this._then);

  final TailscaleRouteTargetReport _self;
  final $Res Function(TailscaleRouteTargetReport) _then;

/// Create a copy of TailscaleRouteTargetReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? state = null,Object? owner = freezed,Object? candidates = null,}) {
  return _then(TailscaleRouteTargetReport(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as TailscaleRouteTarget,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TailscaleRouteState,owner: freezed == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as TailscaleRouteOwner?,candidates: null == candidates ? _self.candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<TailscaleRouteCandidate>,
  ));
}
/// Create a copy of TailscaleRouteTargetReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteTargetCopyWith<$Res> get target {
  
  return $TailscaleRouteTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of TailscaleRouteTargetReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteOwnerCopyWith<$Res>? get owner {
    if (_self.owner == null) {
    return null;
  }

  return $TailscaleRouteOwnerCopyWith<$Res>(_self.owner!, (value) {
    return _then(_self.copyWith(owner: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleRouteTargetReport].
extension TailscaleRouteTargetReportPatterns on TailscaleRouteTargetReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleRouteTargetReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleRouteTargetReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleRouteTargetReport value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteTargetReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleRouteTargetReport value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteTargetReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TailscaleRouteTarget target, @JsonKey(unknownEnumValue: TailscaleRouteState.unconfirmed)  TailscaleRouteState state,  TailscaleRouteOwner? owner,  List<TailscaleRouteCandidate> candidates)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleRouteTargetReport() when $default != null:
return $default(_that.target,_that.state,_that.owner,_that.candidates);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TailscaleRouteTarget target, @JsonKey(unknownEnumValue: TailscaleRouteState.unconfirmed)  TailscaleRouteState state,  TailscaleRouteOwner? owner,  List<TailscaleRouteCandidate> candidates)  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteTargetReport():
return $default(_that.target,_that.state,_that.owner,_that.candidates);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TailscaleRouteTarget target, @JsonKey(unknownEnumValue: TailscaleRouteState.unconfirmed)  TailscaleRouteState state,  TailscaleRouteOwner? owner,  List<TailscaleRouteCandidate> candidates)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteTargetReport() when $default != null:
return $default(_that.target,_that.state,_that.owner,_that.candidates);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleRouteTargetReport implements TailscaleRouteTargetReport {
  const _TailscaleRouteTargetReport({required this.target, @JsonKey(unknownEnumValue: TailscaleRouteState.unconfirmed) this.state = TailscaleRouteState.unconfirmed, this.owner,  List<TailscaleRouteCandidate> candidates = const []}): _candidates = candidates;
  factory _TailscaleRouteTargetReport.fromJson(Map<String, dynamic> json) => _$TailscaleRouteTargetReportFromJson(json);

@override final  TailscaleRouteTarget target;
@override@JsonKey(unknownEnumValue: TailscaleRouteState.unconfirmed) final  TailscaleRouteState state;
@override final  TailscaleRouteOwner? owner;
 final  List<TailscaleRouteCandidate> _candidates;
@override@JsonKey() List<TailscaleRouteCandidate> get candidates {
  if (_candidates is EqualUnmodifiableListView) return _candidates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_candidates);
}


/// Create a copy of TailscaleRouteTargetReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleRouteTargetReportCopyWith<_TailscaleRouteTargetReport> get copyWith => __$TailscaleRouteTargetReportCopyWithImpl<_TailscaleRouteTargetReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleRouteTargetReportToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleRouteTargetReport&&(identical(other.target, target) || other.target == target)&&(identical(other.state, state) || other.state == state)&&(identical(other.owner, owner) || other.owner == owner)&&const DeepCollectionEquality().equals(other.candidates, _candidates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,target,state,owner,const DeepCollectionEquality().hash(_candidates));
}

@override
String toString() {
    return 'TailscaleRouteTargetReport(target: $target, state: $state, owner: $owner, candidates: $candidates)';
}


}

/// @nodoc
abstract mixin class _$TailscaleRouteTargetReportCopyWith<$Res> implements $TailscaleRouteTargetReportCopyWith<$Res> {
  factory _$TailscaleRouteTargetReportCopyWith(_TailscaleRouteTargetReport value, $Res Function(_TailscaleRouteTargetReport) _then) = __$TailscaleRouteTargetReportCopyWithImpl;
@override @useResult
$Res call({
 TailscaleRouteTarget target,@JsonKey(unknownEnumValue: TailscaleRouteState.unconfirmed) TailscaleRouteState state, TailscaleRouteOwner? owner, List<TailscaleRouteCandidate> candidates
});


@override $TailscaleRouteTargetCopyWith<$Res> get target;@override $TailscaleRouteOwnerCopyWith<$Res>? get owner;

}
/// @nodoc
class __$TailscaleRouteTargetReportCopyWithImpl<$Res>
    implements _$TailscaleRouteTargetReportCopyWith<$Res> {
  __$TailscaleRouteTargetReportCopyWithImpl(this._self, this._then);

  final _TailscaleRouteTargetReport _self;
  final $Res Function(_TailscaleRouteTargetReport) _then;

/// Create a copy of TailscaleRouteTargetReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? state = null,Object? owner = freezed,Object? candidates = null,}) {
  return _then(_TailscaleRouteTargetReport(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as TailscaleRouteTarget,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TailscaleRouteState,owner: freezed == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as TailscaleRouteOwner?,candidates: null == candidates ? _self._candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<TailscaleRouteCandidate>,
  ));
}

/// Create a copy of TailscaleRouteTargetReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteTargetCopyWith<$Res> get target {
  
  return $TailscaleRouteTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of TailscaleRouteTargetReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteOwnerCopyWith<$Res>? get owner {
    if (_self.owner == null) {
    return null;
  }

  return $TailscaleRouteOwnerCopyWith<$Res>(_self.owner!, (value) {
    return _then(_self.copyWith(owner: value));
  });
}
}


/// @nodoc
mixin _$TailscaleRouteAccountReport {

 String get id; String get proxy; TailscaleRouteIdentity? get identity; bool get fresh; bool get available;@JsonKey(name: 'logged-out') bool get loggedOut; String get domain; int get addresses;
/// Create a copy of TailscaleRouteAccountReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleRouteAccountReportCopyWith<TailscaleRouteAccountReport> get copyWith => _$TailscaleRouteAccountReportCopyWithImpl<TailscaleRouteAccountReport>(this as TailscaleRouteAccountReport, _$identity);

  /// Serializes this TailscaleRouteAccountReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleRouteAccountReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleRouteAccountReport&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.proxy, _this.proxy) || other.proxy == _this.proxy)&&(identical(other.identity, _this.identity) || other.identity == _this.identity)&&(identical(other.fresh, _this.fresh) || other.fresh == _this.fresh)&&(identical(other.available, _this.available) || other.available == _this.available)&&(identical(other.loggedOut, _this.loggedOut) || other.loggedOut == _this.loggedOut)&&(identical(other.domain, _this.domain) || other.domain == _this.domain)&&(identical(other.addresses, _this.addresses) || other.addresses == _this.addresses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleRouteAccountReport;
  return Object.hash(runtimeType,_this.id,_this.proxy,_this.identity,_this.fresh,_this.available,_this.loggedOut,_this.domain,_this.addresses);
}

@override
String toString() {
  final _this = this as TailscaleRouteAccountReport;
  return 'TailscaleRouteAccountReport(id: ${_this.id}, proxy: ${_this.proxy}, identity: ${_this.identity}, fresh: ${_this.fresh}, available: ${_this.available}, loggedOut: ${_this.loggedOut}, domain: ${_this.domain}, addresses: ${_this.addresses})';
}


}

/// @nodoc
abstract mixin class $TailscaleRouteAccountReportCopyWith<$Res>  {
  factory $TailscaleRouteAccountReportCopyWith(TailscaleRouteAccountReport value, $Res Function(TailscaleRouteAccountReport) _then) = _$TailscaleRouteAccountReportCopyWithImpl;
@useResult
$Res call({
 String id, String proxy, TailscaleRouteIdentity? identity, bool fresh, bool available,@JsonKey(name: 'logged-out') bool loggedOut, String domain, int addresses
});


$TailscaleRouteIdentityCopyWith<$Res>? get identity;

}
/// @nodoc
class _$TailscaleRouteAccountReportCopyWithImpl<$Res>
    implements $TailscaleRouteAccountReportCopyWith<$Res> {
  _$TailscaleRouteAccountReportCopyWithImpl(this._self, this._then);

  final TailscaleRouteAccountReport _self;
  final $Res Function(TailscaleRouteAccountReport) _then;

/// Create a copy of TailscaleRouteAccountReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? proxy = null,Object? identity = freezed,Object? fresh = null,Object? available = null,Object? loggedOut = null,Object? domain = null,Object? addresses = null,}) {
  return _then(TailscaleRouteAccountReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,proxy: null == proxy ? _self.proxy : proxy // ignore: cast_nullable_to_non_nullable
as String,identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as TailscaleRouteIdentity?,fresh: null == fresh ? _self.fresh : fresh // ignore: cast_nullable_to_non_nullable
as bool,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,domain: null == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String,addresses: null == addresses ? _self.addresses : addresses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of TailscaleRouteAccountReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteIdentityCopyWith<$Res>? get identity {
    if (_self.identity == null) {
    return null;
  }

  return $TailscaleRouteIdentityCopyWith<$Res>(_self.identity!, (value) {
    return _then(_self.copyWith(identity: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleRouteAccountReport].
extension TailscaleRouteAccountReportPatterns on TailscaleRouteAccountReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleRouteAccountReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleRouteAccountReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleRouteAccountReport value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteAccountReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleRouteAccountReport value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteAccountReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String proxy,  TailscaleRouteIdentity? identity,  bool fresh,  bool available, @JsonKey(name: 'logged-out')  bool loggedOut,  String domain,  int addresses)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleRouteAccountReport() when $default != null:
return $default(_that.id,_that.proxy,_that.identity,_that.fresh,_that.available,_that.loggedOut,_that.domain,_that.addresses);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String proxy,  TailscaleRouteIdentity? identity,  bool fresh,  bool available, @JsonKey(name: 'logged-out')  bool loggedOut,  String domain,  int addresses)  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteAccountReport():
return $default(_that.id,_that.proxy,_that.identity,_that.fresh,_that.available,_that.loggedOut,_that.domain,_that.addresses);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String proxy,  TailscaleRouteIdentity? identity,  bool fresh,  bool available, @JsonKey(name: 'logged-out')  bool loggedOut,  String domain,  int addresses)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteAccountReport() when $default != null:
return $default(_that.id,_that.proxy,_that.identity,_that.fresh,_that.available,_that.loggedOut,_that.domain,_that.addresses);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleRouteAccountReport implements TailscaleRouteAccountReport {
  const _TailscaleRouteAccountReport({required this.id, this.proxy = '', this.identity, this.fresh = false, this.available = false, @JsonKey(name: 'logged-out') this.loggedOut = false, this.domain = '', this.addresses = 0});
  factory _TailscaleRouteAccountReport.fromJson(Map<String, dynamic> json) => _$TailscaleRouteAccountReportFromJson(json);

@override final  String id;
@override@JsonKey() final  String proxy;
@override final  TailscaleRouteIdentity? identity;
@override@JsonKey() final  bool fresh;
@override@JsonKey() final  bool available;
@override@JsonKey(name: 'logged-out') final  bool loggedOut;
@override@JsonKey() final  String domain;
@override@JsonKey() final  int addresses;

/// Create a copy of TailscaleRouteAccountReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleRouteAccountReportCopyWith<_TailscaleRouteAccountReport> get copyWith => __$TailscaleRouteAccountReportCopyWithImpl<_TailscaleRouteAccountReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleRouteAccountReportToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleRouteAccountReport&&(identical(other.id, id) || other.id == id)&&(identical(other.proxy, proxy) || other.proxy == proxy)&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.fresh, fresh) || other.fresh == fresh)&&(identical(other.available, available) || other.available == available)&&(identical(other.loggedOut, loggedOut) || other.loggedOut == loggedOut)&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.addresses, addresses) || other.addresses == addresses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,proxy,identity,fresh,available,loggedOut,domain,addresses);
}

@override
String toString() {
    return 'TailscaleRouteAccountReport(id: $id, proxy: $proxy, identity: $identity, fresh: $fresh, available: $available, loggedOut: $loggedOut, domain: $domain, addresses: $addresses)';
}


}

/// @nodoc
abstract mixin class _$TailscaleRouteAccountReportCopyWith<$Res> implements $TailscaleRouteAccountReportCopyWith<$Res> {
  factory _$TailscaleRouteAccountReportCopyWith(_TailscaleRouteAccountReport value, $Res Function(_TailscaleRouteAccountReport) _then) = __$TailscaleRouteAccountReportCopyWithImpl;
@override @useResult
$Res call({
 String id, String proxy, TailscaleRouteIdentity? identity, bool fresh, bool available,@JsonKey(name: 'logged-out') bool loggedOut, String domain, int addresses
});


@override $TailscaleRouteIdentityCopyWith<$Res>? get identity;

}
/// @nodoc
class __$TailscaleRouteAccountReportCopyWithImpl<$Res>
    implements _$TailscaleRouteAccountReportCopyWith<$Res> {
  __$TailscaleRouteAccountReportCopyWithImpl(this._self, this._then);

  final _TailscaleRouteAccountReport _self;
  final $Res Function(_TailscaleRouteAccountReport) _then;

/// Create a copy of TailscaleRouteAccountReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? proxy = null,Object? identity = freezed,Object? fresh = null,Object? available = null,Object? loggedOut = null,Object? domain = null,Object? addresses = null,}) {
  return _then(_TailscaleRouteAccountReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,proxy: null == proxy ? _self.proxy : proxy // ignore: cast_nullable_to_non_nullable
as String,identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as TailscaleRouteIdentity?,fresh: null == fresh ? _self.fresh : fresh // ignore: cast_nullable_to_non_nullable
as bool,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,loggedOut: null == loggedOut ? _self.loggedOut : loggedOut // ignore: cast_nullable_to_non_nullable
as bool,domain: null == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String,addresses: null == addresses ? _self.addresses : addresses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of TailscaleRouteAccountReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteIdentityCopyWith<$Res>? get identity {
    if (_self.identity == null) {
    return null;
  }

  return $TailscaleRouteIdentityCopyWith<$Res>(_self.identity!, (value) {
    return _then(_self.copyWith(identity: value));
  });
}
}


/// @nodoc
mixin _$TailscaleRoutes {

@JsonKey(name: 'profile-id') int get profileId; bool get active; bool get complete; bool get saved; bool get unreadable; int get revision; List<TailscaleRouteAccountReport> get accounts; List<TailscaleRouteTargetReport> get targets;@JsonKey(name: 'protected-prefixes') List<String> get protectedPrefixes;@JsonKey(name: 'protected-suffixes') List<String> get protectedSuffixes;
/// Create a copy of TailscaleRoutes
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleRoutesCopyWith<TailscaleRoutes> get copyWith => _$TailscaleRoutesCopyWithImpl<TailscaleRoutes>(this as TailscaleRoutes, _$identity);

  /// Serializes this TailscaleRoutes to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleRoutes;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleRoutes&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&(identical(other.active, _this.active) || other.active == _this.active)&&(identical(other.complete, _this.complete) || other.complete == _this.complete)&&(identical(other.saved, _this.saved) || other.saved == _this.saved)&&(identical(other.unreadable, _this.unreadable) || other.unreadable == _this.unreadable)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&const DeepCollectionEquality().equals(other.accounts, _this.accounts)&&const DeepCollectionEquality().equals(other.targets, _this.targets)&&const DeepCollectionEquality().equals(other.protectedPrefixes, _this.protectedPrefixes)&&const DeepCollectionEquality().equals(other.protectedSuffixes, _this.protectedSuffixes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleRoutes;
  return Object.hash(runtimeType,_this.profileId,_this.active,_this.complete,_this.saved,_this.unreadable,_this.revision,const DeepCollectionEquality().hash(_this.accounts),const DeepCollectionEquality().hash(_this.targets),const DeepCollectionEquality().hash(_this.protectedPrefixes),const DeepCollectionEquality().hash(_this.protectedSuffixes));
}

@override
String toString() {
  final _this = this as TailscaleRoutes;
  return 'TailscaleRoutes(profileId: ${_this.profileId}, active: ${_this.active}, complete: ${_this.complete}, saved: ${_this.saved}, unreadable: ${_this.unreadable}, revision: ${_this.revision}, accounts: ${_this.accounts}, targets: ${_this.targets}, protectedPrefixes: ${_this.protectedPrefixes}, protectedSuffixes: ${_this.protectedSuffixes})';
}


}

/// @nodoc
abstract mixin class $TailscaleRoutesCopyWith<$Res>  {
  factory $TailscaleRoutesCopyWith(TailscaleRoutes value, $Res Function(TailscaleRoutes) _then) = _$TailscaleRoutesCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId, bool active, bool complete, bool saved, bool unreadable, int revision, List<TailscaleRouteAccountReport> accounts, List<TailscaleRouteTargetReport> targets,@JsonKey(name: 'protected-prefixes') List<String> protectedPrefixes,@JsonKey(name: 'protected-suffixes') List<String> protectedSuffixes
});




}
/// @nodoc
class _$TailscaleRoutesCopyWithImpl<$Res>
    implements $TailscaleRoutesCopyWith<$Res> {
  _$TailscaleRoutesCopyWithImpl(this._self, this._then);

  final TailscaleRoutes _self;
  final $Res Function(TailscaleRoutes) _then;

/// Create a copy of TailscaleRoutes
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? active = null,Object? complete = null,Object? saved = null,Object? unreadable = null,Object? revision = null,Object? accounts = null,Object? targets = null,Object? protectedPrefixes = null,Object? protectedSuffixes = null,}) {
  return _then(TailscaleRoutes(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,complete: null == complete ? _self.complete : complete // ignore: cast_nullable_to_non_nullable
as bool,saved: null == saved ? _self.saved : saved // ignore: cast_nullable_to_non_nullable
as bool,unreadable: null == unreadable ? _self.unreadable : unreadable // ignore: cast_nullable_to_non_nullable
as bool,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,accounts: null == accounts ? _self.accounts : accounts // ignore: cast_nullable_to_non_nullable
as List<TailscaleRouteAccountReport>,targets: null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as List<TailscaleRouteTargetReport>,protectedPrefixes: null == protectedPrefixes ? _self.protectedPrefixes : protectedPrefixes // ignore: cast_nullable_to_non_nullable
as List<String>,protectedSuffixes: null == protectedSuffixes ? _self.protectedSuffixes : protectedSuffixes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleRoutes].
extension TailscaleRoutesPatterns on TailscaleRoutes {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleRoutes value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleRoutes() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleRoutes value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleRoutes():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleRoutes value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleRoutes() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId,  bool active,  bool complete,  bool saved,  bool unreadable,  int revision,  List<TailscaleRouteAccountReport> accounts,  List<TailscaleRouteTargetReport> targets, @JsonKey(name: 'protected-prefixes')  List<String> protectedPrefixes, @JsonKey(name: 'protected-suffixes')  List<String> protectedSuffixes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleRoutes() when $default != null:
return $default(_that.profileId,_that.active,_that.complete,_that.saved,_that.unreadable,_that.revision,_that.accounts,_that.targets,_that.protectedPrefixes,_that.protectedSuffixes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId,  bool active,  bool complete,  bool saved,  bool unreadable,  int revision,  List<TailscaleRouteAccountReport> accounts,  List<TailscaleRouteTargetReport> targets, @JsonKey(name: 'protected-prefixes')  List<String> protectedPrefixes, @JsonKey(name: 'protected-suffixes')  List<String> protectedSuffixes)  $default,) {final _that = this;
switch (_that) {
case _TailscaleRoutes():
return $default(_that.profileId,_that.active,_that.complete,_that.saved,_that.unreadable,_that.revision,_that.accounts,_that.targets,_that.protectedPrefixes,_that.protectedSuffixes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'profile-id')  int profileId,  bool active,  bool complete,  bool saved,  bool unreadable,  int revision,  List<TailscaleRouteAccountReport> accounts,  List<TailscaleRouteTargetReport> targets, @JsonKey(name: 'protected-prefixes')  List<String> protectedPrefixes, @JsonKey(name: 'protected-suffixes')  List<String> protectedSuffixes)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleRoutes() when $default != null:
return $default(_that.profileId,_that.active,_that.complete,_that.saved,_that.unreadable,_that.revision,_that.accounts,_that.targets,_that.protectedPrefixes,_that.protectedSuffixes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleRoutes extends TailscaleRoutes {
  const _TailscaleRoutes({@JsonKey(name: 'profile-id') this.profileId = 0, this.active = false, this.complete = false, this.saved = false, this.unreadable = false, this.revision = 0,  List<TailscaleRouteAccountReport> accounts = const [],  List<TailscaleRouteTargetReport> targets = const [], @JsonKey(name: 'protected-prefixes')  List<String> protectedPrefixes = const [], @JsonKey(name: 'protected-suffixes')  List<String> protectedSuffixes = const []}): _accounts = accounts,_targets = targets,_protectedPrefixes = protectedPrefixes,_protectedSuffixes = protectedSuffixes,super._();
  factory _TailscaleRoutes.fromJson(Map<String, dynamic> json) => _$TailscaleRoutesFromJson(json);

@override@JsonKey(name: 'profile-id') final  int profileId;
@override@JsonKey() final  bool active;
@override@JsonKey() final  bool complete;
@override@JsonKey() final  bool saved;
@override@JsonKey() final  bool unreadable;
@override@JsonKey() final  int revision;
 final  List<TailscaleRouteAccountReport> _accounts;
@override@JsonKey() List<TailscaleRouteAccountReport> get accounts {
  if (_accounts is EqualUnmodifiableListView) return _accounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accounts);
}

 final  List<TailscaleRouteTargetReport> _targets;
@override@JsonKey() List<TailscaleRouteTargetReport> get targets {
  if (_targets is EqualUnmodifiableListView) return _targets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_targets);
}

 final  List<String> _protectedPrefixes;
@override@JsonKey(name: 'protected-prefixes') List<String> get protectedPrefixes {
  if (_protectedPrefixes is EqualUnmodifiableListView) return _protectedPrefixes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_protectedPrefixes);
}

 final  List<String> _protectedSuffixes;
@override@JsonKey(name: 'protected-suffixes') List<String> get protectedSuffixes {
  if (_protectedSuffixes is EqualUnmodifiableListView) return _protectedSuffixes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_protectedSuffixes);
}


/// Create a copy of TailscaleRoutes
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleRoutesCopyWith<_TailscaleRoutes> get copyWith => __$TailscaleRoutesCopyWithImpl<_TailscaleRoutes>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleRoutesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleRoutes&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.active, active) || other.active == active)&&(identical(other.complete, complete) || other.complete == complete)&&(identical(other.saved, saved) || other.saved == saved)&&(identical(other.unreadable, unreadable) || other.unreadable == unreadable)&&(identical(other.revision, revision) || other.revision == revision)&&const DeepCollectionEquality().equals(other.accounts, _accounts)&&const DeepCollectionEquality().equals(other.targets, _targets)&&const DeepCollectionEquality().equals(other.protectedPrefixes, _protectedPrefixes)&&const DeepCollectionEquality().equals(other.protectedSuffixes, _protectedSuffixes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,profileId,active,complete,saved,unreadable,revision,const DeepCollectionEquality().hash(_accounts),const DeepCollectionEquality().hash(_targets),const DeepCollectionEquality().hash(_protectedPrefixes),const DeepCollectionEquality().hash(_protectedSuffixes));
}

@override
String toString() {
    return 'TailscaleRoutes(profileId: $profileId, active: $active, complete: $complete, saved: $saved, unreadable: $unreadable, revision: $revision, accounts: $accounts, targets: $targets, protectedPrefixes: $protectedPrefixes, protectedSuffixes: $protectedSuffixes)';
}


}

/// @nodoc
abstract mixin class _$TailscaleRoutesCopyWith<$Res> implements $TailscaleRoutesCopyWith<$Res> {
  factory _$TailscaleRoutesCopyWith(_TailscaleRoutes value, $Res Function(_TailscaleRoutes) _then) = __$TailscaleRoutesCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId, bool active, bool complete, bool saved, bool unreadable, int revision, List<TailscaleRouteAccountReport> accounts, List<TailscaleRouteTargetReport> targets,@JsonKey(name: 'protected-prefixes') List<String> protectedPrefixes,@JsonKey(name: 'protected-suffixes') List<String> protectedSuffixes
});




}
/// @nodoc
class __$TailscaleRoutesCopyWithImpl<$Res>
    implements _$TailscaleRoutesCopyWith<$Res> {
  __$TailscaleRoutesCopyWithImpl(this._self, this._then);

  final _TailscaleRoutes _self;
  final $Res Function(_TailscaleRoutes) _then;

/// Create a copy of TailscaleRoutes
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? active = null,Object? complete = null,Object? saved = null,Object? unreadable = null,Object? revision = null,Object? accounts = null,Object? targets = null,Object? protectedPrefixes = null,Object? protectedSuffixes = null,}) {
  return _then(_TailscaleRoutes(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,complete: null == complete ? _self.complete : complete // ignore: cast_nullable_to_non_nullable
as bool,saved: null == saved ? _self.saved : saved // ignore: cast_nullable_to_non_nullable
as bool,unreadable: null == unreadable ? _self.unreadable : unreadable // ignore: cast_nullable_to_non_nullable
as bool,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,accounts: null == accounts ? _self._accounts : accounts // ignore: cast_nullable_to_non_nullable
as List<TailscaleRouteAccountReport>,targets: null == targets ? _self._targets : targets // ignore: cast_nullable_to_non_nullable
as List<TailscaleRouteTargetReport>,protectedPrefixes: null == protectedPrefixes ? _self._protectedPrefixes : protectedPrefixes // ignore: cast_nullable_to_non_nullable
as List<String>,protectedSuffixes: null == protectedSuffixes ? _self._protectedSuffixes : protectedSuffixes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$TailscaleRouteAssignment {

 TailscaleRouteTarget get target; TailscaleRouteOwner get owner;
/// Create a copy of TailscaleRouteAssignment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleRouteAssignmentCopyWith<TailscaleRouteAssignment> get copyWith => _$TailscaleRouteAssignmentCopyWithImpl<TailscaleRouteAssignment>(this as TailscaleRouteAssignment, _$identity);

  /// Serializes this TailscaleRouteAssignment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleRouteAssignment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleRouteAssignment&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.owner, _this.owner) || other.owner == _this.owner));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleRouteAssignment;
  return Object.hash(runtimeType,_this.target,_this.owner);
}

@override
String toString() {
  final _this = this as TailscaleRouteAssignment;
  return 'TailscaleRouteAssignment(target: ${_this.target}, owner: ${_this.owner})';
}


}

/// @nodoc
abstract mixin class $TailscaleRouteAssignmentCopyWith<$Res>  {
  factory $TailscaleRouteAssignmentCopyWith(TailscaleRouteAssignment value, $Res Function(TailscaleRouteAssignment) _then) = _$TailscaleRouteAssignmentCopyWithImpl;
@useResult
$Res call({
 TailscaleRouteTarget target, TailscaleRouteOwner owner
});


$TailscaleRouteTargetCopyWith<$Res> get target;$TailscaleRouteOwnerCopyWith<$Res> get owner;

}
/// @nodoc
class _$TailscaleRouteAssignmentCopyWithImpl<$Res>
    implements $TailscaleRouteAssignmentCopyWith<$Res> {
  _$TailscaleRouteAssignmentCopyWithImpl(this._self, this._then);

  final TailscaleRouteAssignment _self;
  final $Res Function(TailscaleRouteAssignment) _then;

/// Create a copy of TailscaleRouteAssignment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? owner = null,}) {
  return _then(TailscaleRouteAssignment(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as TailscaleRouteTarget,owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as TailscaleRouteOwner,
  ));
}
/// Create a copy of TailscaleRouteAssignment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteTargetCopyWith<$Res> get target {
  
  return $TailscaleRouteTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of TailscaleRouteAssignment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteOwnerCopyWith<$Res> get owner {
  
  return $TailscaleRouteOwnerCopyWith<$Res>(_self.owner, (value) {
    return _then(_self.copyWith(owner: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleRouteAssignment].
extension TailscaleRouteAssignmentPatterns on TailscaleRouteAssignment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleRouteAssignment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleRouteAssignment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleRouteAssignment value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteAssignment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleRouteAssignment value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleRouteAssignment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TailscaleRouteTarget target,  TailscaleRouteOwner owner)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleRouteAssignment() when $default != null:
return $default(_that.target,_that.owner);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TailscaleRouteTarget target,  TailscaleRouteOwner owner)  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteAssignment():
return $default(_that.target,_that.owner);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TailscaleRouteTarget target,  TailscaleRouteOwner owner)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleRouteAssignment() when $default != null:
return $default(_that.target,_that.owner);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleRouteAssignment implements TailscaleRouteAssignment {
  const _TailscaleRouteAssignment({required this.target, required this.owner});
  factory _TailscaleRouteAssignment.fromJson(Map<String, dynamic> json) => _$TailscaleRouteAssignmentFromJson(json);

@override final  TailscaleRouteTarget target;
@override final  TailscaleRouteOwner owner;

/// Create a copy of TailscaleRouteAssignment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleRouteAssignmentCopyWith<_TailscaleRouteAssignment> get copyWith => __$TailscaleRouteAssignmentCopyWithImpl<_TailscaleRouteAssignment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleRouteAssignmentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleRouteAssignment&&(identical(other.target, target) || other.target == target)&&(identical(other.owner, owner) || other.owner == owner));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,target,owner);
}

@override
String toString() {
    return 'TailscaleRouteAssignment(target: $target, owner: $owner)';
}


}

/// @nodoc
abstract mixin class _$TailscaleRouteAssignmentCopyWith<$Res> implements $TailscaleRouteAssignmentCopyWith<$Res> {
  factory _$TailscaleRouteAssignmentCopyWith(_TailscaleRouteAssignment value, $Res Function(_TailscaleRouteAssignment) _then) = __$TailscaleRouteAssignmentCopyWithImpl;
@override @useResult
$Res call({
 TailscaleRouteTarget target, TailscaleRouteOwner owner
});


@override $TailscaleRouteTargetCopyWith<$Res> get target;@override $TailscaleRouteOwnerCopyWith<$Res> get owner;

}
/// @nodoc
class __$TailscaleRouteAssignmentCopyWithImpl<$Res>
    implements _$TailscaleRouteAssignmentCopyWith<$Res> {
  __$TailscaleRouteAssignmentCopyWithImpl(this._self, this._then);

  final _TailscaleRouteAssignment _self;
  final $Res Function(_TailscaleRouteAssignment) _then;

/// Create a copy of TailscaleRouteAssignment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? owner = null,}) {
  return _then(_TailscaleRouteAssignment(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as TailscaleRouteTarget,owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as TailscaleRouteOwner,
  ));
}

/// Create a copy of TailscaleRouteAssignment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteTargetCopyWith<$Res> get target {
  
  return $TailscaleRouteTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of TailscaleRouteAssignment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRouteOwnerCopyWith<$Res> get owner {
  
  return $TailscaleRouteOwnerCopyWith<$Res>(_self.owner, (value) {
    return _then(_self.copyWith(owner: value));
  });
}
}


/// @nodoc
mixin _$TailscaleAssignResult {

 String get outcome; TailscaleRoutes? get routes; TailscaleError? get error;
/// Create a copy of TailscaleAssignResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleAssignResultCopyWith<TailscaleAssignResult> get copyWith => _$TailscaleAssignResultCopyWithImpl<TailscaleAssignResult>(this as TailscaleAssignResult, _$identity);

  /// Serializes this TailscaleAssignResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleAssignResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleAssignResult&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.routes, _this.routes) || other.routes == _this.routes)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleAssignResult;
  return Object.hash(runtimeType,_this.outcome,_this.routes,_this.error);
}

@override
String toString() {
  final _this = this as TailscaleAssignResult;
  return 'TailscaleAssignResult(outcome: ${_this.outcome}, routes: ${_this.routes}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $TailscaleAssignResultCopyWith<$Res>  {
  factory $TailscaleAssignResultCopyWith(TailscaleAssignResult value, $Res Function(TailscaleAssignResult) _then) = _$TailscaleAssignResultCopyWithImpl;
@useResult
$Res call({
 String outcome, TailscaleRoutes? routes, TailscaleError? error
});


$TailscaleRoutesCopyWith<$Res>? get routes;$TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$TailscaleAssignResultCopyWithImpl<$Res>
    implements $TailscaleAssignResultCopyWith<$Res> {
  _$TailscaleAssignResultCopyWithImpl(this._self, this._then);

  final TailscaleAssignResult _self;
  final $Res Function(TailscaleAssignResult) _then;

/// Create a copy of TailscaleAssignResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? outcome = null,Object? routes = freezed,Object? error = freezed,}) {
  return _then(TailscaleAssignResult(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as String,routes: freezed == routes ? _self.routes : routes // ignore: cast_nullable_to_non_nullable
as TailscaleRoutes?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}
/// Create a copy of TailscaleAssignResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRoutesCopyWith<$Res>? get routes {
    if (_self.routes == null) {
    return null;
  }

  return $TailscaleRoutesCopyWith<$Res>(_self.routes!, (value) {
    return _then(_self.copyWith(routes: value));
  });
}/// Create a copy of TailscaleAssignResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleAssignResult].
extension TailscaleAssignResultPatterns on TailscaleAssignResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleAssignResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleAssignResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleAssignResult value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleAssignResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleAssignResult value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleAssignResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String outcome,  TailscaleRoutes? routes,  TailscaleError? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleAssignResult() when $default != null:
return $default(_that.outcome,_that.routes,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String outcome,  TailscaleRoutes? routes,  TailscaleError? error)  $default,) {final _that = this;
switch (_that) {
case _TailscaleAssignResult():
return $default(_that.outcome,_that.routes,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String outcome,  TailscaleRoutes? routes,  TailscaleError? error)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleAssignResult() when $default != null:
return $default(_that.outcome,_that.routes,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleAssignResult implements TailscaleAssignResult {
  const _TailscaleAssignResult({this.outcome = '', this.routes, this.error});
  factory _TailscaleAssignResult.fromJson(Map<String, dynamic> json) => _$TailscaleAssignResultFromJson(json);

@override@JsonKey() final  String outcome;
@override final  TailscaleRoutes? routes;
@override final  TailscaleError? error;

/// Create a copy of TailscaleAssignResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleAssignResultCopyWith<_TailscaleAssignResult> get copyWith => __$TailscaleAssignResultCopyWithImpl<_TailscaleAssignResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleAssignResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleAssignResult&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.routes, routes) || other.routes == routes)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,outcome,routes,error);
}

@override
String toString() {
    return 'TailscaleAssignResult(outcome: $outcome, routes: $routes, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TailscaleAssignResultCopyWith<$Res> implements $TailscaleAssignResultCopyWith<$Res> {
  factory _$TailscaleAssignResultCopyWith(_TailscaleAssignResult value, $Res Function(_TailscaleAssignResult) _then) = __$TailscaleAssignResultCopyWithImpl;
@override @useResult
$Res call({
 String outcome, TailscaleRoutes? routes, TailscaleError? error
});


@override $TailscaleRoutesCopyWith<$Res>? get routes;@override $TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class __$TailscaleAssignResultCopyWithImpl<$Res>
    implements _$TailscaleAssignResultCopyWith<$Res> {
  __$TailscaleAssignResultCopyWithImpl(this._self, this._then);

  final _TailscaleAssignResult _self;
  final $Res Function(_TailscaleAssignResult) _then;

/// Create a copy of TailscaleAssignResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? outcome = null,Object? routes = freezed,Object? error = freezed,}) {
  return _then(_TailscaleAssignResult(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as String,routes: freezed == routes ? _self.routes : routes // ignore: cast_nullable_to_non_nullable
as TailscaleRoutes?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}

/// Create a copy of TailscaleAssignResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleRoutesCopyWith<$Res>? get routes {
    if (_self.routes == null) {
    return null;
  }

  return $TailscaleRoutesCopyWith<$Res>(_self.routes!, (value) {
    return _then(_self.copyWith(routes: value));
  });
}/// Create a copy of TailscaleAssignResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$TailscaleForgetResult {

 String get outcome; TailscaleError? get error;
/// Create a copy of TailscaleForgetResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleForgetResultCopyWith<TailscaleForgetResult> get copyWith => _$TailscaleForgetResultCopyWithImpl<TailscaleForgetResult>(this as TailscaleForgetResult, _$identity);

  /// Serializes this TailscaleForgetResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleForgetResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleForgetResult&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleForgetResult;
  return Object.hash(runtimeType,_this.outcome,_this.error);
}

@override
String toString() {
  final _this = this as TailscaleForgetResult;
  return 'TailscaleForgetResult(outcome: ${_this.outcome}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $TailscaleForgetResultCopyWith<$Res>  {
  factory $TailscaleForgetResultCopyWith(TailscaleForgetResult value, $Res Function(TailscaleForgetResult) _then) = _$TailscaleForgetResultCopyWithImpl;
@useResult
$Res call({
 String outcome, TailscaleError? error
});


$TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$TailscaleForgetResultCopyWithImpl<$Res>
    implements $TailscaleForgetResultCopyWith<$Res> {
  _$TailscaleForgetResultCopyWithImpl(this._self, this._then);

  final TailscaleForgetResult _self;
  final $Res Function(TailscaleForgetResult) _then;

/// Create a copy of TailscaleForgetResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? outcome = null,Object? error = freezed,}) {
  return _then(TailscaleForgetResult(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}
/// Create a copy of TailscaleForgetResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [TailscaleForgetResult].
extension TailscaleForgetResultPatterns on TailscaleForgetResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleForgetResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleForgetResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleForgetResult value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleForgetResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleForgetResult value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleForgetResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String outcome,  TailscaleError? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleForgetResult() when $default != null:
return $default(_that.outcome,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String outcome,  TailscaleError? error)  $default,) {final _that = this;
switch (_that) {
case _TailscaleForgetResult():
return $default(_that.outcome,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String outcome,  TailscaleError? error)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleForgetResult() when $default != null:
return $default(_that.outcome,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleForgetResult implements TailscaleForgetResult {
  const _TailscaleForgetResult({this.outcome = '', this.error});
  factory _TailscaleForgetResult.fromJson(Map<String, dynamic> json) => _$TailscaleForgetResultFromJson(json);

@override@JsonKey() final  String outcome;
@override final  TailscaleError? error;

/// Create a copy of TailscaleForgetResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleForgetResultCopyWith<_TailscaleForgetResult> get copyWith => __$TailscaleForgetResultCopyWithImpl<_TailscaleForgetResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleForgetResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleForgetResult&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,outcome,error);
}

@override
String toString() {
    return 'TailscaleForgetResult(outcome: $outcome, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TailscaleForgetResultCopyWith<$Res> implements $TailscaleForgetResultCopyWith<$Res> {
  factory _$TailscaleForgetResultCopyWith(_TailscaleForgetResult value, $Res Function(_TailscaleForgetResult) _then) = __$TailscaleForgetResultCopyWithImpl;
@override @useResult
$Res call({
 String outcome, TailscaleError? error
});


@override $TailscaleErrorCopyWith<$Res>? get error;

}
/// @nodoc
class __$TailscaleForgetResultCopyWithImpl<$Res>
    implements _$TailscaleForgetResultCopyWith<$Res> {
  __$TailscaleForgetResultCopyWithImpl(this._self, this._then);

  final _TailscaleForgetResult _self;
  final $Res Function(_TailscaleForgetResult) _then;

/// Create a copy of TailscaleForgetResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? outcome = null,Object? error = freezed,}) {
  return _then(_TailscaleForgetResult(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TailscaleError?,
  ));
}

/// Create a copy of TailscaleForgetResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TailscaleErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TailscaleErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$TailscaleRoutesEvent {

@JsonKey(name: 'profile-id') int get profileId; int get revision;
/// Create a copy of TailscaleRoutesEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleRoutesEventCopyWith<TailscaleRoutesEvent> get copyWith => _$TailscaleRoutesEventCopyWithImpl<TailscaleRoutesEvent>(this as TailscaleRoutesEvent, _$identity);

  /// Serializes this TailscaleRoutesEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TailscaleRoutesEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleRoutesEvent&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&(identical(other.revision, _this.revision) || other.revision == _this.revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TailscaleRoutesEvent;
  return Object.hash(runtimeType,_this.profileId,_this.revision);
}

@override
String toString() {
  final _this = this as TailscaleRoutesEvent;
  return 'TailscaleRoutesEvent(profileId: ${_this.profileId}, revision: ${_this.revision})';
}


}

/// @nodoc
abstract mixin class $TailscaleRoutesEventCopyWith<$Res>  {
  factory $TailscaleRoutesEventCopyWith(TailscaleRoutesEvent value, $Res Function(TailscaleRoutesEvent) _then) = _$TailscaleRoutesEventCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId, int revision
});




}
/// @nodoc
class _$TailscaleRoutesEventCopyWithImpl<$Res>
    implements $TailscaleRoutesEventCopyWith<$Res> {
  _$TailscaleRoutesEventCopyWithImpl(this._self, this._then);

  final TailscaleRoutesEvent _self;
  final $Res Function(TailscaleRoutesEvent) _then;

/// Create a copy of TailscaleRoutesEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? revision = null,}) {
  return _then(TailscaleRoutesEvent(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleRoutesEvent].
extension TailscaleRoutesEventPatterns on TailscaleRoutesEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleRoutesEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleRoutesEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleRoutesEvent value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleRoutesEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleRoutesEvent value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleRoutesEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleRoutesEvent() when $default != null:
return $default(_that.profileId,_that.revision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'profile-id')  int profileId,  int revision)  $default,) {final _that = this;
switch (_that) {
case _TailscaleRoutesEvent():
return $default(_that.profileId,_that.revision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'profile-id')  int profileId,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleRoutesEvent() when $default != null:
return $default(_that.profileId,_that.revision);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TailscaleRoutesEvent implements TailscaleRoutesEvent {
  const _TailscaleRoutesEvent({@JsonKey(name: 'profile-id') this.profileId = 0, this.revision = 0});
  factory _TailscaleRoutesEvent.fromJson(Map<String, dynamic> json) => _$TailscaleRoutesEventFromJson(json);

@override@JsonKey(name: 'profile-id') final  int profileId;
@override@JsonKey() final  int revision;

/// Create a copy of TailscaleRoutesEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleRoutesEventCopyWith<_TailscaleRoutesEvent> get copyWith => __$TailscaleRoutesEventCopyWithImpl<_TailscaleRoutesEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TailscaleRoutesEventToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleRoutesEvent&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,profileId,revision);
}

@override
String toString() {
    return 'TailscaleRoutesEvent(profileId: $profileId, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$TailscaleRoutesEventCopyWith<$Res> implements $TailscaleRoutesEventCopyWith<$Res> {
  factory _$TailscaleRoutesEventCopyWith(_TailscaleRoutesEvent value, $Res Function(_TailscaleRoutesEvent) _then) = __$TailscaleRoutesEventCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'profile-id') int profileId, int revision
});




}
/// @nodoc
class __$TailscaleRoutesEventCopyWithImpl<$Res>
    implements _$TailscaleRoutesEventCopyWith<$Res> {
  __$TailscaleRoutesEventCopyWithImpl(this._self, this._then);

  final _TailscaleRoutesEvent _self;
  final $Res Function(_TailscaleRoutesEvent) _then;

/// Create a copy of TailscaleRoutesEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? revision = null,}) {
  return _then(_TailscaleRoutesEvent(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$TailscaleManagedPanel {

 TailscaleAttachState get attach; TailscaleManagedNotice? get notice; bool get removing; bool get preparing;
/// Create a copy of TailscaleManagedPanel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TailscaleManagedPanelCopyWith<TailscaleManagedPanel> get copyWith => _$TailscaleManagedPanelCopyWithImpl<TailscaleManagedPanel>(this as TailscaleManagedPanel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TailscaleManagedPanel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TailscaleManagedPanel&&(identical(other.attach, _this.attach) || other.attach == _this.attach)&&(identical(other.notice, _this.notice) || other.notice == _this.notice)&&(identical(other.removing, _this.removing) || other.removing == _this.removing)&&(identical(other.preparing, _this.preparing) || other.preparing == _this.preparing));
}


@override
int get hashCode {
  final _this = this as TailscaleManagedPanel;
  return Object.hash(runtimeType,_this.attach,_this.notice,_this.removing,_this.preparing);
}

@override
String toString() {
  final _this = this as TailscaleManagedPanel;
  return 'TailscaleManagedPanel(attach: ${_this.attach}, notice: ${_this.notice}, removing: ${_this.removing}, preparing: ${_this.preparing})';
}


}

/// @nodoc
abstract mixin class $TailscaleManagedPanelCopyWith<$Res>  {
  factory $TailscaleManagedPanelCopyWith(TailscaleManagedPanel value, $Res Function(TailscaleManagedPanel) _then) = _$TailscaleManagedPanelCopyWithImpl;
@useResult
$Res call({
 TailscaleAttachState attach, TailscaleManagedNotice? notice, bool removing, bool preparing
});




}
/// @nodoc
class _$TailscaleManagedPanelCopyWithImpl<$Res>
    implements $TailscaleManagedPanelCopyWith<$Res> {
  _$TailscaleManagedPanelCopyWithImpl(this._self, this._then);

  final TailscaleManagedPanel _self;
  final $Res Function(TailscaleManagedPanel) _then;

/// Create a copy of TailscaleManagedPanel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? attach = null,Object? notice = freezed,Object? removing = null,Object? preparing = null,}) {
  return _then(TailscaleManagedPanel(
attach: null == attach ? _self.attach : attach // ignore: cast_nullable_to_non_nullable
as TailscaleAttachState,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as TailscaleManagedNotice?,removing: null == removing ? _self.removing : removing // ignore: cast_nullable_to_non_nullable
as bool,preparing: null == preparing ? _self.preparing : preparing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TailscaleManagedPanel].
extension TailscaleManagedPanelPatterns on TailscaleManagedPanel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TailscaleManagedPanel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TailscaleManagedPanel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TailscaleManagedPanel value)  $default,){
final _that = this;
switch (_that) {
case _TailscaleManagedPanel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TailscaleManagedPanel value)?  $default,){
final _that = this;
switch (_that) {
case _TailscaleManagedPanel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TailscaleAttachState attach,  TailscaleManagedNotice? notice,  bool removing,  bool preparing)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TailscaleManagedPanel() when $default != null:
return $default(_that.attach,_that.notice,_that.removing,_that.preparing);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TailscaleAttachState attach,  TailscaleManagedNotice? notice,  bool removing,  bool preparing)  $default,) {final _that = this;
switch (_that) {
case _TailscaleManagedPanel():
return $default(_that.attach,_that.notice,_that.removing,_that.preparing);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TailscaleAttachState attach,  TailscaleManagedNotice? notice,  bool removing,  bool preparing)?  $default,) {final _that = this;
switch (_that) {
case _TailscaleManagedPanel() when $default != null:
return $default(_that.attach,_that.notice,_that.removing,_that.preparing);case _:
  return null;

}
}

}

/// @nodoc


class _TailscaleManagedPanel implements TailscaleManagedPanel {
  const _TailscaleManagedPanel({this.attach = TailscaleAttachState.none, this.notice, this.removing = false, this.preparing = false});
  

@override@JsonKey() final  TailscaleAttachState attach;
@override final  TailscaleManagedNotice? notice;
@override@JsonKey() final  bool removing;
@override@JsonKey() final  bool preparing;

/// Create a copy of TailscaleManagedPanel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TailscaleManagedPanelCopyWith<_TailscaleManagedPanel> get copyWith => __$TailscaleManagedPanelCopyWithImpl<_TailscaleManagedPanel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TailscaleManagedPanel&&(identical(other.attach, attach) || other.attach == attach)&&(identical(other.notice, notice) || other.notice == notice)&&(identical(other.removing, removing) || other.removing == removing)&&(identical(other.preparing, preparing) || other.preparing == preparing));
}


@override
int get hashCode {
    return Object.hash(runtimeType,attach,notice,removing,preparing);
}

@override
String toString() {
    return 'TailscaleManagedPanel(attach: $attach, notice: $notice, removing: $removing, preparing: $preparing)';
}


}

/// @nodoc
abstract mixin class _$TailscaleManagedPanelCopyWith<$Res> implements $TailscaleManagedPanelCopyWith<$Res> {
  factory _$TailscaleManagedPanelCopyWith(_TailscaleManagedPanel value, $Res Function(_TailscaleManagedPanel) _then) = __$TailscaleManagedPanelCopyWithImpl;
@override @useResult
$Res call({
 TailscaleAttachState attach, TailscaleManagedNotice? notice, bool removing, bool preparing
});




}
/// @nodoc
class __$TailscaleManagedPanelCopyWithImpl<$Res>
    implements _$TailscaleManagedPanelCopyWith<$Res> {
  __$TailscaleManagedPanelCopyWithImpl(this._self, this._then);

  final _TailscaleManagedPanel _self;
  final $Res Function(_TailscaleManagedPanel) _then;

/// Create a copy of TailscaleManagedPanel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? attach = null,Object? notice = freezed,Object? removing = null,Object? preparing = null,}) {
  return _then(_TailscaleManagedPanel(
attach: null == attach ? _self.attach : attach // ignore: cast_nullable_to_non_nullable
as TailscaleAttachState,notice: freezed == notice ? _self.notice : notice // ignore: cast_nullable_to_non_nullable
as TailscaleManagedNotice?,removing: null == removing ? _self.removing : removing // ignore: cast_nullable_to_non_nullable
as bool,preparing: null == preparing ? _self.preparing : preparing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
