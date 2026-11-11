// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../mount.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MountSource {

 int get id; String get label; String get path;
/// Create a copy of MountSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountSourceCopyWith<MountSource> get copyWith => _$MountSourceCopyWithImpl<MountSource>(this as MountSource, _$identity);

  /// Serializes this MountSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountSource&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.path, _this.path) || other.path == _this.path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountSource;
  return Object.hash(runtimeType,_this.id,_this.label,_this.path);
}

@override
String toString() {
  final _this = this as MountSource;
  return 'MountSource(id: ${_this.id}, label: ${_this.label}, path: ${_this.path})';
}


}

/// @nodoc
abstract mixin class $MountSourceCopyWith<$Res>  {
  factory $MountSourceCopyWith(MountSource value, $Res Function(MountSource) _then) = _$MountSourceCopyWithImpl;
@useResult
$Res call({
 int id, String label, String path
});




}
/// @nodoc
class _$MountSourceCopyWithImpl<$Res>
    implements $MountSourceCopyWith<$Res> {
  _$MountSourceCopyWithImpl(this._self, this._then);

  final MountSource _self;
  final $Res Function(MountSource) _then;

/// Create a copy of MountSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? path = null,}) {
  return _then(MountSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MountSource].
extension MountSourcePatterns on MountSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountSource value)  $default,){
final _that = this;
switch (_that) {
case _MountSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountSource value)?  $default,){
final _that = this;
switch (_that) {
case _MountSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String label,  String path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountSource() when $default != null:
return $default(_that.id,_that.label,_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String label,  String path)  $default,) {final _that = this;
switch (_that) {
case _MountSource():
return $default(_that.id,_that.label,_that.path);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String label,  String path)?  $default,) {final _that = this;
switch (_that) {
case _MountSource() when $default != null:
return $default(_that.id,_that.label,_that.path);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountSource implements MountSource {
  const _MountSource({required this.id, required this.label, required this.path});
  factory _MountSource.fromJson(Map<String, dynamic> json) => _$MountSourceFromJson(json);

@override final  int id;
@override final  String label;
@override final  String path;

/// Create a copy of MountSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountSourceCopyWith<_MountSource> get copyWith => __$MountSourceCopyWithImpl<_MountSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountSourceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountSource&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,label,path);
}

@override
String toString() {
    return 'MountSource(id: $id, label: $label, path: $path)';
}


}

/// @nodoc
abstract mixin class _$MountSourceCopyWith<$Res> implements $MountSourceCopyWith<$Res> {
  factory _$MountSourceCopyWith(_MountSource value, $Res Function(_MountSource) _then) = __$MountSourceCopyWithImpl;
@override @useResult
$Res call({
 int id, String label, String path
});




}
/// @nodoc
class __$MountSourceCopyWithImpl<$Res>
    implements _$MountSourceCopyWith<$Res> {
  __$MountSourceCopyWithImpl(this._self, this._then);

  final _MountSource _self;
  final $Res Function(_MountSource) _then;

/// Create a copy of MountSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? path = null,}) {
  return _then(_MountSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MountSetup {

 int get target; String get revision; List<MountSource> get sources; List<String> get groups;
/// Create a copy of MountSetup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountSetupCopyWith<MountSetup> get copyWith => _$MountSetupCopyWithImpl<MountSetup>(this as MountSetup, _$identity);

  /// Serializes this MountSetup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountSetup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountSetup&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&const DeepCollectionEquality().equals(other.sources, _this.sources)&&const DeepCollectionEquality().equals(other.groups, _this.groups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountSetup;
  return Object.hash(runtimeType,_this.target,_this.revision,const DeepCollectionEquality().hash(_this.sources),const DeepCollectionEquality().hash(_this.groups));
}

@override
String toString() {
  final _this = this as MountSetup;
  return 'MountSetup(target: ${_this.target}, revision: ${_this.revision}, sources: ${_this.sources}, groups: ${_this.groups})';
}


}

/// @nodoc
abstract mixin class $MountSetupCopyWith<$Res>  {
  factory $MountSetupCopyWith(MountSetup value, $Res Function(MountSetup) _then) = _$MountSetupCopyWithImpl;
@useResult
$Res call({
 int target, String revision, List<MountSource> sources, List<String> groups
});




}
/// @nodoc
class _$MountSetupCopyWithImpl<$Res>
    implements $MountSetupCopyWith<$Res> {
  _$MountSetupCopyWithImpl(this._self, this._then);

  final MountSetup _self;
  final $Res Function(MountSetup) _then;

/// Create a copy of MountSetup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? revision = null,Object? sources = null,Object? groups = null,}) {
  return _then(MountSetup(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<MountSource>,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [MountSetup].
extension MountSetupPatterns on MountSetup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountSetup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountSetup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountSetup value)  $default,){
final _that = this;
switch (_that) {
case _MountSetup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountSetup value)?  $default,){
final _that = this;
switch (_that) {
case _MountSetup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int target,  String revision,  List<MountSource> sources,  List<String> groups)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountSetup() when $default != null:
return $default(_that.target,_that.revision,_that.sources,_that.groups);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int target,  String revision,  List<MountSource> sources,  List<String> groups)  $default,) {final _that = this;
switch (_that) {
case _MountSetup():
return $default(_that.target,_that.revision,_that.sources,_that.groups);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int target,  String revision,  List<MountSource> sources,  List<String> groups)?  $default,) {final _that = this;
switch (_that) {
case _MountSetup() when $default != null:
return $default(_that.target,_that.revision,_that.sources,_that.groups);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountSetup implements MountSetup {
  const _MountSetup({required this.target, required this.revision,  List<MountSource> sources = const [],  List<String> groups = const []}): _sources = sources,_groups = groups;
  factory _MountSetup.fromJson(Map<String, dynamic> json) => _$MountSetupFromJson(json);

@override final  int target;
@override final  String revision;
 final  List<MountSource> _sources;
@override@JsonKey() List<MountSource> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}

 final  List<String> _groups;
@override@JsonKey() List<String> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}


/// Create a copy of MountSetup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountSetupCopyWith<_MountSetup> get copyWith => __$MountSetupCopyWithImpl<_MountSetup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountSetupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountSetup&&(identical(other.target, target) || other.target == target)&&(identical(other.revision, revision) || other.revision == revision)&&const DeepCollectionEquality().equals(other.sources, _sources)&&const DeepCollectionEquality().equals(other.groups, _groups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,target,revision,const DeepCollectionEquality().hash(_sources),const DeepCollectionEquality().hash(_groups));
}

@override
String toString() {
    return 'MountSetup(target: $target, revision: $revision, sources: $sources, groups: $groups)';
}


}

/// @nodoc
abstract mixin class _$MountSetupCopyWith<$Res> implements $MountSetupCopyWith<$Res> {
  factory _$MountSetupCopyWith(_MountSetup value, $Res Function(_MountSetup) _then) = __$MountSetupCopyWithImpl;
@override @useResult
$Res call({
 int target, String revision, List<MountSource> sources, List<String> groups
});




}
/// @nodoc
class __$MountSetupCopyWithImpl<$Res>
    implements _$MountSetupCopyWith<$Res> {
  __$MountSetupCopyWithImpl(this._self, this._then);

  final _MountSetup _self;
  final $Res Function(_MountSetup) _then;

/// Create a copy of MountSetup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? revision = null,Object? sources = null,Object? groups = null,}) {
  return _then(_MountSetup(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<MountSource>,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$MountOperation {

 MountOperationKind get kind; int get version; List<int> get sourceIds;
/// Create a copy of MountOperation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountOperationCopyWith<MountOperation> get copyWith => _$MountOperationCopyWithImpl<MountOperation>(this as MountOperation, _$identity);

  /// Serializes this MountOperation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountOperation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountOperation&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.version, _this.version) || other.version == _this.version)&&const DeepCollectionEquality().equals(other.sourceIds, _this.sourceIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountOperation;
  return Object.hash(runtimeType,_this.kind,_this.version,const DeepCollectionEquality().hash(_this.sourceIds));
}

@override
String toString() {
  final _this = this as MountOperation;
  return 'MountOperation(kind: ${_this.kind}, version: ${_this.version}, sourceIds: ${_this.sourceIds})';
}


}

/// @nodoc
abstract mixin class $MountOperationCopyWith<$Res>  {
  factory $MountOperationCopyWith(MountOperation value, $Res Function(MountOperation) _then) = _$MountOperationCopyWithImpl;
@useResult
$Res call({
 MountOperationKind kind, int version, List<int> sourceIds
});




}
/// @nodoc
class _$MountOperationCopyWithImpl<$Res>
    implements $MountOperationCopyWith<$Res> {
  _$MountOperationCopyWithImpl(this._self, this._then);

  final MountOperation _self;
  final $Res Function(MountOperation) _then;

/// Create a copy of MountOperation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? version = null,Object? sourceIds = null,}) {
  return _then(MountOperation(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MountOperationKind,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,sourceIds: null == sourceIds ? _self.sourceIds : sourceIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [MountOperation].
extension MountOperationPatterns on MountOperation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountOperation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountOperation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountOperation value)  $default,){
final _that = this;
switch (_that) {
case _MountOperation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountOperation value)?  $default,){
final _that = this;
switch (_that) {
case _MountOperation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MountOperationKind kind,  int version,  List<int> sourceIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountOperation() when $default != null:
return $default(_that.kind,_that.version,_that.sourceIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MountOperationKind kind,  int version,  List<int> sourceIds)  $default,) {final _that = this;
switch (_that) {
case _MountOperation():
return $default(_that.kind,_that.version,_that.sourceIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MountOperationKind kind,  int version,  List<int> sourceIds)?  $default,) {final _that = this;
switch (_that) {
case _MountOperation() when $default != null:
return $default(_that.kind,_that.version,_that.sourceIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountOperation implements MountOperation {
  const _MountOperation({required this.kind, required this.version,  List<int> sourceIds = const []}): _sourceIds = sourceIds;
  factory _MountOperation.fromJson(Map<String, dynamic> json) => _$MountOperationFromJson(json);

@override final  MountOperationKind kind;
@override final  int version;
 final  List<int> _sourceIds;
@override@JsonKey() List<int> get sourceIds {
  if (_sourceIds is EqualUnmodifiableListView) return _sourceIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sourceIds);
}


/// Create a copy of MountOperation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountOperationCopyWith<_MountOperation> get copyWith => __$MountOperationCopyWithImpl<_MountOperation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountOperationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountOperation&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.sourceIds, _sourceIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,version,const DeepCollectionEquality().hash(_sourceIds));
}

@override
String toString() {
    return 'MountOperation(kind: $kind, version: $version, sourceIds: $sourceIds)';
}


}

/// @nodoc
abstract mixin class _$MountOperationCopyWith<$Res> implements $MountOperationCopyWith<$Res> {
  factory _$MountOperationCopyWith(_MountOperation value, $Res Function(_MountOperation) _then) = __$MountOperationCopyWithImpl;
@override @useResult
$Res call({
 MountOperationKind kind, int version, List<int> sourceIds
});




}
/// @nodoc
class __$MountOperationCopyWithImpl<$Res>
    implements _$MountOperationCopyWith<$Res> {
  __$MountOperationCopyWithImpl(this._self, this._then);

  final _MountOperation _self;
  final $Res Function(_MountOperation) _then;

/// Create a copy of MountOperation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? version = null,Object? sourceIds = null,}) {
  return _then(_MountOperation(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MountOperationKind,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,sourceIds: null == sourceIds ? _self._sourceIds : sourceIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

/// @nodoc
mixin _$MountTargetState {

 int get targetId; List<int> get sourceIds; List<String> get groups; int get version; MountOperation? get pending;
/// Create a copy of MountTargetState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountTargetStateCopyWith<MountTargetState> get copyWith => _$MountTargetStateCopyWithImpl<MountTargetState>(this as MountTargetState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MountTargetState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountTargetState&&(identical(other.targetId, _this.targetId) || other.targetId == _this.targetId)&&const DeepCollectionEquality().equals(other.sourceIds, _this.sourceIds)&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.pending, _this.pending) || other.pending == _this.pending));
}


@override
int get hashCode {
  final _this = this as MountTargetState;
  return Object.hash(runtimeType,_this.targetId,const DeepCollectionEquality().hash(_this.sourceIds),const DeepCollectionEquality().hash(_this.groups),_this.version,_this.pending);
}

@override
String toString() {
  final _this = this as MountTargetState;
  return 'MountTargetState(targetId: ${_this.targetId}, sourceIds: ${_this.sourceIds}, groups: ${_this.groups}, version: ${_this.version}, pending: ${_this.pending})';
}


}

/// @nodoc
abstract mixin class $MountTargetStateCopyWith<$Res>  {
  factory $MountTargetStateCopyWith(MountTargetState value, $Res Function(MountTargetState) _then) = _$MountTargetStateCopyWithImpl;
@useResult
$Res call({
 int targetId, List<int> sourceIds, List<String> groups, int version, MountOperation? pending
});


$MountOperationCopyWith<$Res>? get pending;

}
/// @nodoc
class _$MountTargetStateCopyWithImpl<$Res>
    implements $MountTargetStateCopyWith<$Res> {
  _$MountTargetStateCopyWithImpl(this._self, this._then);

  final MountTargetState _self;
  final $Res Function(MountTargetState) _then;

/// Create a copy of MountTargetState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? targetId = null,Object? sourceIds = null,Object? groups = null,Object? version = null,Object? pending = freezed,}) {
  return _then(MountTargetState(
targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as int,sourceIds: null == sourceIds ? _self.sourceIds : sourceIds // ignore: cast_nullable_to_non_nullable
as List<int>,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<String>,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,pending: freezed == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as MountOperation?,
  ));
}
/// Create a copy of MountTargetState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountOperationCopyWith<$Res>? get pending {
    if (_self.pending == null) {
    return null;
  }

  return $MountOperationCopyWith<$Res>(_self.pending!, (value) {
    return _then(_self.copyWith(pending: value));
  });
}
}


/// Adds pattern-matching-related methods to [MountTargetState].
extension MountTargetStatePatterns on MountTargetState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountTargetState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountTargetState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountTargetState value)  $default,){
final _that = this;
switch (_that) {
case _MountTargetState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountTargetState value)?  $default,){
final _that = this;
switch (_that) {
case _MountTargetState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int targetId,  List<int> sourceIds,  List<String> groups,  int version,  MountOperation? pending)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountTargetState() when $default != null:
return $default(_that.targetId,_that.sourceIds,_that.groups,_that.version,_that.pending);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int targetId,  List<int> sourceIds,  List<String> groups,  int version,  MountOperation? pending)  $default,) {final _that = this;
switch (_that) {
case _MountTargetState():
return $default(_that.targetId,_that.sourceIds,_that.groups,_that.version,_that.pending);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int targetId,  List<int> sourceIds,  List<String> groups,  int version,  MountOperation? pending)?  $default,) {final _that = this;
switch (_that) {
case _MountTargetState() when $default != null:
return $default(_that.targetId,_that.sourceIds,_that.groups,_that.version,_that.pending);case _:
  return null;

}
}

}

/// @nodoc


class _MountTargetState implements MountTargetState {
  const _MountTargetState({required this.targetId,  List<int> sourceIds = const [],  List<String> groups = const [], required this.version, this.pending}): _sourceIds = sourceIds,_groups = groups;
  

@override final  int targetId;
 final  List<int> _sourceIds;
@override@JsonKey() List<int> get sourceIds {
  if (_sourceIds is EqualUnmodifiableListView) return _sourceIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sourceIds);
}

 final  List<String> _groups;
@override@JsonKey() List<String> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

@override final  int version;
@override final  MountOperation? pending;

/// Create a copy of MountTargetState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountTargetStateCopyWith<_MountTargetState> get copyWith => __$MountTargetStateCopyWithImpl<_MountTargetState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountTargetState&&(identical(other.targetId, targetId) || other.targetId == targetId)&&const DeepCollectionEquality().equals(other.sourceIds, _sourceIds)&&const DeepCollectionEquality().equals(other.groups, _groups)&&(identical(other.version, version) || other.version == version)&&(identical(other.pending, pending) || other.pending == pending));
}


@override
int get hashCode {
    return Object.hash(runtimeType,targetId,const DeepCollectionEquality().hash(_sourceIds),const DeepCollectionEquality().hash(_groups),version,pending);
}

@override
String toString() {
    return 'MountTargetState(targetId: $targetId, sourceIds: $sourceIds, groups: $groups, version: $version, pending: $pending)';
}


}

/// @nodoc
abstract mixin class _$MountTargetStateCopyWith<$Res> implements $MountTargetStateCopyWith<$Res> {
  factory _$MountTargetStateCopyWith(_MountTargetState value, $Res Function(_MountTargetState) _then) = __$MountTargetStateCopyWithImpl;
@override @useResult
$Res call({
 int targetId, List<int> sourceIds, List<String> groups, int version, MountOperation? pending
});


@override $MountOperationCopyWith<$Res>? get pending;

}
/// @nodoc
class __$MountTargetStateCopyWithImpl<$Res>
    implements _$MountTargetStateCopyWith<$Res> {
  __$MountTargetStateCopyWithImpl(this._self, this._then);

  final _MountTargetState _self;
  final $Res Function(_MountTargetState) _then;

/// Create a copy of MountTargetState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? targetId = null,Object? sourceIds = null,Object? groups = null,Object? version = null,Object? pending = freezed,}) {
  return _then(_MountTargetState(
targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as int,sourceIds: null == sourceIds ? _self._sourceIds : sourceIds // ignore: cast_nullable_to_non_nullable
as List<int>,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<String>,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,pending: freezed == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as MountOperation?,
  ));
}

/// Create a copy of MountTargetState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountOperationCopyWith<$Res>? get pending {
    if (_self.pending == null) {
    return null;
  }

  return $MountOperationCopyWith<$Res>(_self.pending!, (value) {
    return _then(_self.copyWith(pending: value));
  });
}
}

/// @nodoc
mixin _$MountSourceRecord {

 int get sourceId; MountSourceFailure? get failure; DateTime? get failedAt; DateTime? get succeededAt;
/// Create a copy of MountSourceRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountSourceRecordCopyWith<MountSourceRecord> get copyWith => _$MountSourceRecordCopyWithImpl<MountSourceRecord>(this as MountSourceRecord, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MountSourceRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountSourceRecord&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.failure, _this.failure) || other.failure == _this.failure)&&(identical(other.failedAt, _this.failedAt) || other.failedAt == _this.failedAt)&&(identical(other.succeededAt, _this.succeededAt) || other.succeededAt == _this.succeededAt));
}


@override
int get hashCode {
  final _this = this as MountSourceRecord;
  return Object.hash(runtimeType,_this.sourceId,_this.failure,_this.failedAt,_this.succeededAt);
}

@override
String toString() {
  final _this = this as MountSourceRecord;
  return 'MountSourceRecord(sourceId: ${_this.sourceId}, failure: ${_this.failure}, failedAt: ${_this.failedAt}, succeededAt: ${_this.succeededAt})';
}


}

/// @nodoc
abstract mixin class $MountSourceRecordCopyWith<$Res>  {
  factory $MountSourceRecordCopyWith(MountSourceRecord value, $Res Function(MountSourceRecord) _then) = _$MountSourceRecordCopyWithImpl;
@useResult
$Res call({
 int sourceId, MountSourceFailure? failure, DateTime? failedAt, DateTime? succeededAt
});




}
/// @nodoc
class _$MountSourceRecordCopyWithImpl<$Res>
    implements $MountSourceRecordCopyWith<$Res> {
  _$MountSourceRecordCopyWithImpl(this._self, this._then);

  final MountSourceRecord _self;
  final $Res Function(MountSourceRecord) _then;

/// Create a copy of MountSourceRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? failure = freezed,Object? failedAt = freezed,Object? succeededAt = freezed,}) {
  return _then(MountSourceRecord(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as MountSourceFailure?,failedAt: freezed == failedAt ? _self.failedAt : failedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,succeededAt: freezed == succeededAt ? _self.succeededAt : succeededAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MountSourceRecord].
extension MountSourceRecordPatterns on MountSourceRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountSourceRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountSourceRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountSourceRecord value)  $default,){
final _that = this;
switch (_that) {
case _MountSourceRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountSourceRecord value)?  $default,){
final _that = this;
switch (_that) {
case _MountSourceRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sourceId,  MountSourceFailure? failure,  DateTime? failedAt,  DateTime? succeededAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountSourceRecord() when $default != null:
return $default(_that.sourceId,_that.failure,_that.failedAt,_that.succeededAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sourceId,  MountSourceFailure? failure,  DateTime? failedAt,  DateTime? succeededAt)  $default,) {final _that = this;
switch (_that) {
case _MountSourceRecord():
return $default(_that.sourceId,_that.failure,_that.failedAt,_that.succeededAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sourceId,  MountSourceFailure? failure,  DateTime? failedAt,  DateTime? succeededAt)?  $default,) {final _that = this;
switch (_that) {
case _MountSourceRecord() when $default != null:
return $default(_that.sourceId,_that.failure,_that.failedAt,_that.succeededAt);case _:
  return null;

}
}

}

/// @nodoc


class _MountSourceRecord implements MountSourceRecord {
  const _MountSourceRecord({required this.sourceId, this.failure, this.failedAt, this.succeededAt});
  

@override final  int sourceId;
@override final  MountSourceFailure? failure;
@override final  DateTime? failedAt;
@override final  DateTime? succeededAt;

/// Create a copy of MountSourceRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountSourceRecordCopyWith<_MountSourceRecord> get copyWith => __$MountSourceRecordCopyWithImpl<_MountSourceRecord>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountSourceRecord&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.failedAt, failedAt) || other.failedAt == failedAt)&&(identical(other.succeededAt, succeededAt) || other.succeededAt == succeededAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceId,failure,failedAt,succeededAt);
}

@override
String toString() {
    return 'MountSourceRecord(sourceId: $sourceId, failure: $failure, failedAt: $failedAt, succeededAt: $succeededAt)';
}


}

/// @nodoc
abstract mixin class _$MountSourceRecordCopyWith<$Res> implements $MountSourceRecordCopyWith<$Res> {
  factory _$MountSourceRecordCopyWith(_MountSourceRecord value, $Res Function(_MountSourceRecord) _then) = __$MountSourceRecordCopyWithImpl;
@override @useResult
$Res call({
 int sourceId, MountSourceFailure? failure, DateTime? failedAt, DateTime? succeededAt
});




}
/// @nodoc
class __$MountSourceRecordCopyWithImpl<$Res>
    implements _$MountSourceRecordCopyWith<$Res> {
  __$MountSourceRecordCopyWithImpl(this._self, this._then);

  final _MountSourceRecord _self;
  final $Res Function(_MountSourceRecord) _then;

/// Create a copy of MountSourceRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? failure = freezed,Object? failedAt = freezed,Object? succeededAt = freezed,}) {
  return _then(_MountSourceRecord(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as MountSourceFailure?,failedAt: freezed == failedAt ? _self.failedAt : failedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,succeededAt: freezed == succeededAt ? _self.succeededAt : succeededAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$MountSourceInspection {

 MountSourceStatus get status; int get count; int get listed;@JsonKey(name: 'tailscale-excluded') int get tailscaleExcluded;@JsonKey(name: 'relay-excluded') int get relayExcluded;
/// Create a copy of MountSourceInspection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountSourceInspectionCopyWith<MountSourceInspection> get copyWith => _$MountSourceInspectionCopyWithImpl<MountSourceInspection>(this as MountSourceInspection, _$identity);

  /// Serializes this MountSourceInspection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountSourceInspection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountSourceInspection&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.count, _this.count) || other.count == _this.count)&&(identical(other.listed, _this.listed) || other.listed == _this.listed)&&(identical(other.tailscaleExcluded, _this.tailscaleExcluded) || other.tailscaleExcluded == _this.tailscaleExcluded)&&(identical(other.relayExcluded, _this.relayExcluded) || other.relayExcluded == _this.relayExcluded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountSourceInspection;
  return Object.hash(runtimeType,_this.status,_this.count,_this.listed,_this.tailscaleExcluded,_this.relayExcluded);
}

@override
String toString() {
  final _this = this as MountSourceInspection;
  return 'MountSourceInspection(status: ${_this.status}, count: ${_this.count}, listed: ${_this.listed}, tailscaleExcluded: ${_this.tailscaleExcluded}, relayExcluded: ${_this.relayExcluded})';
}


}

/// @nodoc
abstract mixin class $MountSourceInspectionCopyWith<$Res>  {
  factory $MountSourceInspectionCopyWith(MountSourceInspection value, $Res Function(MountSourceInspection) _then) = _$MountSourceInspectionCopyWithImpl;
@useResult
$Res call({
 MountSourceStatus status, int count, int listed,@JsonKey(name: 'tailscale-excluded') int tailscaleExcluded,@JsonKey(name: 'relay-excluded') int relayExcluded
});




}
/// @nodoc
class _$MountSourceInspectionCopyWithImpl<$Res>
    implements $MountSourceInspectionCopyWith<$Res> {
  _$MountSourceInspectionCopyWithImpl(this._self, this._then);

  final MountSourceInspection _self;
  final $Res Function(MountSourceInspection) _then;

/// Create a copy of MountSourceInspection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? count = null,Object? listed = null,Object? tailscaleExcluded = null,Object? relayExcluded = null,}) {
  return _then(MountSourceInspection(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MountSourceStatus,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,listed: null == listed ? _self.listed : listed // ignore: cast_nullable_to_non_nullable
as int,tailscaleExcluded: null == tailscaleExcluded ? _self.tailscaleExcluded : tailscaleExcluded // ignore: cast_nullable_to_non_nullable
as int,relayExcluded: null == relayExcluded ? _self.relayExcluded : relayExcluded // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MountSourceInspection].
extension MountSourceInspectionPatterns on MountSourceInspection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountSourceInspection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountSourceInspection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountSourceInspection value)  $default,){
final _that = this;
switch (_that) {
case _MountSourceInspection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountSourceInspection value)?  $default,){
final _that = this;
switch (_that) {
case _MountSourceInspection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MountSourceStatus status,  int count,  int listed, @JsonKey(name: 'tailscale-excluded')  int tailscaleExcluded, @JsonKey(name: 'relay-excluded')  int relayExcluded)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountSourceInspection() when $default != null:
return $default(_that.status,_that.count,_that.listed,_that.tailscaleExcluded,_that.relayExcluded);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MountSourceStatus status,  int count,  int listed, @JsonKey(name: 'tailscale-excluded')  int tailscaleExcluded, @JsonKey(name: 'relay-excluded')  int relayExcluded)  $default,) {final _that = this;
switch (_that) {
case _MountSourceInspection():
return $default(_that.status,_that.count,_that.listed,_that.tailscaleExcluded,_that.relayExcluded);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MountSourceStatus status,  int count,  int listed, @JsonKey(name: 'tailscale-excluded')  int tailscaleExcluded, @JsonKey(name: 'relay-excluded')  int relayExcluded)?  $default,) {final _that = this;
switch (_that) {
case _MountSourceInspection() when $default != null:
return $default(_that.status,_that.count,_that.listed,_that.tailscaleExcluded,_that.relayExcluded);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountSourceInspection implements MountSourceInspection {
  const _MountSourceInspection({required this.status, this.count = 0, this.listed = 0, @JsonKey(name: 'tailscale-excluded') this.tailscaleExcluded = 0, @JsonKey(name: 'relay-excluded') this.relayExcluded = 0});
  factory _MountSourceInspection.fromJson(Map<String, dynamic> json) => _$MountSourceInspectionFromJson(json);

@override final  MountSourceStatus status;
@override@JsonKey() final  int count;
@override@JsonKey() final  int listed;
@override@JsonKey(name: 'tailscale-excluded') final  int tailscaleExcluded;
@override@JsonKey(name: 'relay-excluded') final  int relayExcluded;

/// Create a copy of MountSourceInspection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountSourceInspectionCopyWith<_MountSourceInspection> get copyWith => __$MountSourceInspectionCopyWithImpl<_MountSourceInspection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountSourceInspectionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountSourceInspection&&(identical(other.status, status) || other.status == status)&&(identical(other.count, count) || other.count == count)&&(identical(other.listed, listed) || other.listed == listed)&&(identical(other.tailscaleExcluded, tailscaleExcluded) || other.tailscaleExcluded == tailscaleExcluded)&&(identical(other.relayExcluded, relayExcluded) || other.relayExcluded == relayExcluded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,count,listed,tailscaleExcluded,relayExcluded);
}

@override
String toString() {
    return 'MountSourceInspection(status: $status, count: $count, listed: $listed, tailscaleExcluded: $tailscaleExcluded, relayExcluded: $relayExcluded)';
}


}

/// @nodoc
abstract mixin class _$MountSourceInspectionCopyWith<$Res> implements $MountSourceInspectionCopyWith<$Res> {
  factory _$MountSourceInspectionCopyWith(_MountSourceInspection value, $Res Function(_MountSourceInspection) _then) = __$MountSourceInspectionCopyWithImpl;
@override @useResult
$Res call({
 MountSourceStatus status, int count, int listed,@JsonKey(name: 'tailscale-excluded') int tailscaleExcluded,@JsonKey(name: 'relay-excluded') int relayExcluded
});




}
/// @nodoc
class __$MountSourceInspectionCopyWithImpl<$Res>
    implements _$MountSourceInspectionCopyWith<$Res> {
  __$MountSourceInspectionCopyWithImpl(this._self, this._then);

  final _MountSourceInspection _self;
  final $Res Function(_MountSourceInspection) _then;

/// Create a copy of MountSourceInspection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? count = null,Object? listed = null,Object? tailscaleExcluded = null,Object? relayExcluded = null,}) {
  return _then(_MountSourceInspection(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MountSourceStatus,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,listed: null == listed ? _self.listed : listed // ignore: cast_nullable_to_non_nullable
as int,tailscaleExcluded: null == tailscaleExcluded ? _self.tailscaleExcluded : tailscaleExcluded // ignore: cast_nullable_to_non_nullable
as int,relayExcluded: null == relayExcluded ? _self.relayExcluded : relayExcluded // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$MountGroupInfo {

 String get name; String get type; MountGroupKind get kind; MountGroupExclusion? get excluded; MountGroupCollects? get collects; bool get hidden; bool get filter;@JsonKey(name: 'exclude-filter') bool get excludeFilter;@JsonKey(name: 'exclude-type') bool get excludeType; bool get uses; MountGroupProbe get probe;@JsonKey(name: 'empty-fallback') String? get emptyFallback;
/// Create a copy of MountGroupInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountGroupInfoCopyWith<MountGroupInfo> get copyWith => _$MountGroupInfoCopyWithImpl<MountGroupInfo>(this as MountGroupInfo, _$identity);

  /// Serializes this MountGroupInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountGroupInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountGroupInfo&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.excluded, _this.excluded) || other.excluded == _this.excluded)&&(identical(other.collects, _this.collects) || other.collects == _this.collects)&&(identical(other.hidden, _this.hidden) || other.hidden == _this.hidden)&&(identical(other.filter, _this.filter) || other.filter == _this.filter)&&(identical(other.excludeFilter, _this.excludeFilter) || other.excludeFilter == _this.excludeFilter)&&(identical(other.excludeType, _this.excludeType) || other.excludeType == _this.excludeType)&&(identical(other.uses, _this.uses) || other.uses == _this.uses)&&(identical(other.probe, _this.probe) || other.probe == _this.probe)&&(identical(other.emptyFallback, _this.emptyFallback) || other.emptyFallback == _this.emptyFallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountGroupInfo;
  return Object.hash(runtimeType,_this.name,_this.type,_this.kind,_this.excluded,_this.collects,_this.hidden,_this.filter,_this.excludeFilter,_this.excludeType,_this.uses,_this.probe,_this.emptyFallback);
}

@override
String toString() {
  final _this = this as MountGroupInfo;
  return 'MountGroupInfo(name: ${_this.name}, type: ${_this.type}, kind: ${_this.kind}, excluded: ${_this.excluded}, collects: ${_this.collects}, hidden: ${_this.hidden}, filter: ${_this.filter}, excludeFilter: ${_this.excludeFilter}, excludeType: ${_this.excludeType}, uses: ${_this.uses}, probe: ${_this.probe}, emptyFallback: ${_this.emptyFallback})';
}


}

/// @nodoc
abstract mixin class $MountGroupInfoCopyWith<$Res>  {
  factory $MountGroupInfoCopyWith(MountGroupInfo value, $Res Function(MountGroupInfo) _then) = _$MountGroupInfoCopyWithImpl;
@useResult
$Res call({
 String name, String type, MountGroupKind kind, MountGroupExclusion? excluded, MountGroupCollects? collects, bool hidden, bool filter,@JsonKey(name: 'exclude-filter') bool excludeFilter,@JsonKey(name: 'exclude-type') bool excludeType, bool uses, MountGroupProbe probe,@JsonKey(name: 'empty-fallback') String? emptyFallback
});




}
/// @nodoc
class _$MountGroupInfoCopyWithImpl<$Res>
    implements $MountGroupInfoCopyWith<$Res> {
  _$MountGroupInfoCopyWithImpl(this._self, this._then);

  final MountGroupInfo _self;
  final $Res Function(MountGroupInfo) _then;

/// Create a copy of MountGroupInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? type = null,Object? kind = null,Object? excluded = freezed,Object? collects = freezed,Object? hidden = null,Object? filter = null,Object? excludeFilter = null,Object? excludeType = null,Object? uses = null,Object? probe = null,Object? emptyFallback = freezed,}) {
  return _then(MountGroupInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MountGroupKind,excluded: freezed == excluded ? _self.excluded : excluded // ignore: cast_nullable_to_non_nullable
as MountGroupExclusion?,collects: freezed == collects ? _self.collects : collects // ignore: cast_nullable_to_non_nullable
as MountGroupCollects?,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as bool,excludeFilter: null == excludeFilter ? _self.excludeFilter : excludeFilter // ignore: cast_nullable_to_non_nullable
as bool,excludeType: null == excludeType ? _self.excludeType : excludeType // ignore: cast_nullable_to_non_nullable
as bool,uses: null == uses ? _self.uses : uses // ignore: cast_nullable_to_non_nullable
as bool,probe: null == probe ? _self.probe : probe // ignore: cast_nullable_to_non_nullable
as MountGroupProbe,emptyFallback: freezed == emptyFallback ? _self.emptyFallback : emptyFallback // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MountGroupInfo].
extension MountGroupInfoPatterns on MountGroupInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountGroupInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountGroupInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountGroupInfo value)  $default,){
final _that = this;
switch (_that) {
case _MountGroupInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountGroupInfo value)?  $default,){
final _that = this;
switch (_that) {
case _MountGroupInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String type,  MountGroupKind kind,  MountGroupExclusion? excluded,  MountGroupCollects? collects,  bool hidden,  bool filter, @JsonKey(name: 'exclude-filter')  bool excludeFilter, @JsonKey(name: 'exclude-type')  bool excludeType,  bool uses,  MountGroupProbe probe, @JsonKey(name: 'empty-fallback')  String? emptyFallback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountGroupInfo() when $default != null:
return $default(_that.name,_that.type,_that.kind,_that.excluded,_that.collects,_that.hidden,_that.filter,_that.excludeFilter,_that.excludeType,_that.uses,_that.probe,_that.emptyFallback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String type,  MountGroupKind kind,  MountGroupExclusion? excluded,  MountGroupCollects? collects,  bool hidden,  bool filter, @JsonKey(name: 'exclude-filter')  bool excludeFilter, @JsonKey(name: 'exclude-type')  bool excludeType,  bool uses,  MountGroupProbe probe, @JsonKey(name: 'empty-fallback')  String? emptyFallback)  $default,) {final _that = this;
switch (_that) {
case _MountGroupInfo():
return $default(_that.name,_that.type,_that.kind,_that.excluded,_that.collects,_that.hidden,_that.filter,_that.excludeFilter,_that.excludeType,_that.uses,_that.probe,_that.emptyFallback);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String type,  MountGroupKind kind,  MountGroupExclusion? excluded,  MountGroupCollects? collects,  bool hidden,  bool filter, @JsonKey(name: 'exclude-filter')  bool excludeFilter, @JsonKey(name: 'exclude-type')  bool excludeType,  bool uses,  MountGroupProbe probe, @JsonKey(name: 'empty-fallback')  String? emptyFallback)?  $default,) {final _that = this;
switch (_that) {
case _MountGroupInfo() when $default != null:
return $default(_that.name,_that.type,_that.kind,_that.excluded,_that.collects,_that.hidden,_that.filter,_that.excludeFilter,_that.excludeType,_that.uses,_that.probe,_that.emptyFallback);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountGroupInfo implements MountGroupInfo {
  const _MountGroupInfo({required this.name, required this.type, required this.kind, this.excluded, this.collects, this.hidden = false, this.filter = false, @JsonKey(name: 'exclude-filter') this.excludeFilter = false, @JsonKey(name: 'exclude-type') this.excludeType = false, this.uses = false, this.probe = MountGroupProbe.none, @JsonKey(name: 'empty-fallback') this.emptyFallback});
  factory _MountGroupInfo.fromJson(Map<String, dynamic> json) => _$MountGroupInfoFromJson(json);

@override final  String name;
@override final  String type;
@override final  MountGroupKind kind;
@override final  MountGroupExclusion? excluded;
@override final  MountGroupCollects? collects;
@override@JsonKey() final  bool hidden;
@override@JsonKey() final  bool filter;
@override@JsonKey(name: 'exclude-filter') final  bool excludeFilter;
@override@JsonKey(name: 'exclude-type') final  bool excludeType;
@override@JsonKey() final  bool uses;
@override@JsonKey() final  MountGroupProbe probe;
@override@JsonKey(name: 'empty-fallback') final  String? emptyFallback;

/// Create a copy of MountGroupInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountGroupInfoCopyWith<_MountGroupInfo> get copyWith => __$MountGroupInfoCopyWithImpl<_MountGroupInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountGroupInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountGroupInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.excluded, excluded) || other.excluded == excluded)&&(identical(other.collects, collects) || other.collects == collects)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.excludeFilter, excludeFilter) || other.excludeFilter == excludeFilter)&&(identical(other.excludeType, excludeType) || other.excludeType == excludeType)&&(identical(other.uses, uses) || other.uses == uses)&&(identical(other.probe, probe) || other.probe == probe)&&(identical(other.emptyFallback, emptyFallback) || other.emptyFallback == emptyFallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,type,kind,excluded,collects,hidden,filter,excludeFilter,excludeType,uses,probe,emptyFallback);
}

@override
String toString() {
    return 'MountGroupInfo(name: $name, type: $type, kind: $kind, excluded: $excluded, collects: $collects, hidden: $hidden, filter: $filter, excludeFilter: $excludeFilter, excludeType: $excludeType, uses: $uses, probe: $probe, emptyFallback: $emptyFallback)';
}


}

/// @nodoc
abstract mixin class _$MountGroupInfoCopyWith<$Res> implements $MountGroupInfoCopyWith<$Res> {
  factory _$MountGroupInfoCopyWith(_MountGroupInfo value, $Res Function(_MountGroupInfo) _then) = __$MountGroupInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, String type, MountGroupKind kind, MountGroupExclusion? excluded, MountGroupCollects? collects, bool hidden, bool filter,@JsonKey(name: 'exclude-filter') bool excludeFilter,@JsonKey(name: 'exclude-type') bool excludeType, bool uses, MountGroupProbe probe,@JsonKey(name: 'empty-fallback') String? emptyFallback
});




}
/// @nodoc
class __$MountGroupInfoCopyWithImpl<$Res>
    implements _$MountGroupInfoCopyWith<$Res> {
  __$MountGroupInfoCopyWithImpl(this._self, this._then);

  final _MountGroupInfo _self;
  final $Res Function(_MountGroupInfo) _then;

/// Create a copy of MountGroupInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? type = null,Object? kind = null,Object? excluded = freezed,Object? collects = freezed,Object? hidden = null,Object? filter = null,Object? excludeFilter = null,Object? excludeType = null,Object? uses = null,Object? probe = null,Object? emptyFallback = freezed,}) {
  return _then(_MountGroupInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MountGroupKind,excluded: freezed == excluded ? _self.excluded : excluded // ignore: cast_nullable_to_non_nullable
as MountGroupExclusion?,collects: freezed == collects ? _self.collects : collects // ignore: cast_nullable_to_non_nullable
as MountGroupCollects?,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as bool,excludeFilter: null == excludeFilter ? _self.excludeFilter : excludeFilter // ignore: cast_nullable_to_non_nullable
as bool,excludeType: null == excludeType ? _self.excludeType : excludeType // ignore: cast_nullable_to_non_nullable
as bool,uses: null == uses ? _self.uses : uses // ignore: cast_nullable_to_non_nullable
as bool,probe: null == probe ? _self.probe : probe // ignore: cast_nullable_to_non_nullable
as MountGroupProbe,emptyFallback: freezed == emptyFallback ? _self.emptyFallback : emptyFallback // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MountTarget {

 List<MountGroupInfo> get groups; List<String> get relay;
/// Create a copy of MountTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountTargetCopyWith<MountTarget> get copyWith => _$MountTargetCopyWithImpl<MountTarget>(this as MountTarget, _$identity);

  /// Serializes this MountTarget to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountTarget;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountTarget&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&const DeepCollectionEquality().equals(other.relay, _this.relay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountTarget;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.groups),const DeepCollectionEquality().hash(_this.relay));
}

@override
String toString() {
  final _this = this as MountTarget;
  return 'MountTarget(groups: ${_this.groups}, relay: ${_this.relay})';
}


}

/// @nodoc
abstract mixin class $MountTargetCopyWith<$Res>  {
  factory $MountTargetCopyWith(MountTarget value, $Res Function(MountTarget) _then) = _$MountTargetCopyWithImpl;
@useResult
$Res call({
 List<MountGroupInfo> groups, List<String> relay
});




}
/// @nodoc
class _$MountTargetCopyWithImpl<$Res>
    implements $MountTargetCopyWith<$Res> {
  _$MountTargetCopyWithImpl(this._self, this._then);

  final MountTarget _self;
  final $Res Function(MountTarget) _then;

/// Create a copy of MountTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groups = null,Object? relay = null,}) {
  return _then(MountTarget(
groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<MountGroupInfo>,relay: null == relay ? _self.relay : relay // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [MountTarget].
extension MountTargetPatterns on MountTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountTarget value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountTarget() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountTarget value)  $default,){
final _that = this;
switch (_that) {
case _MountTarget():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountTarget value)?  $default,){
final _that = this;
switch (_that) {
case _MountTarget() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MountGroupInfo> groups,  List<String> relay)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountTarget() when $default != null:
return $default(_that.groups,_that.relay);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MountGroupInfo> groups,  List<String> relay)  $default,) {final _that = this;
switch (_that) {
case _MountTarget():
return $default(_that.groups,_that.relay);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MountGroupInfo> groups,  List<String> relay)?  $default,) {final _that = this;
switch (_that) {
case _MountTarget() when $default != null:
return $default(_that.groups,_that.relay);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountTarget implements MountTarget {
  const _MountTarget({ List<MountGroupInfo> groups = const [],  List<String> relay = const []}): _groups = groups,_relay = relay;
  factory _MountTarget.fromJson(Map<String, dynamic> json) => _$MountTargetFromJson(json);

 final  List<MountGroupInfo> _groups;
@override@JsonKey() List<MountGroupInfo> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

 final  List<String> _relay;
@override@JsonKey() List<String> get relay {
  if (_relay is EqualUnmodifiableListView) return _relay;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_relay);
}


/// Create a copy of MountTarget
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountTargetCopyWith<_MountTarget> get copyWith => __$MountTargetCopyWithImpl<_MountTarget>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountTargetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountTarget&&const DeepCollectionEquality().equals(other.groups, _groups)&&const DeepCollectionEquality().equals(other.relay, _relay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_groups),const DeepCollectionEquality().hash(_relay));
}

@override
String toString() {
    return 'MountTarget(groups: $groups, relay: $relay)';
}


}

/// @nodoc
abstract mixin class _$MountTargetCopyWith<$Res> implements $MountTargetCopyWith<$Res> {
  factory _$MountTargetCopyWith(_MountTarget value, $Res Function(_MountTarget) _then) = __$MountTargetCopyWithImpl;
@override @useResult
$Res call({
 List<MountGroupInfo> groups, List<String> relay
});




}
/// @nodoc
class __$MountTargetCopyWithImpl<$Res>
    implements _$MountTargetCopyWith<$Res> {
  __$MountTargetCopyWithImpl(this._self, this._then);

  final _MountTarget _self;
  final $Res Function(_MountTarget) _then;

/// Create a copy of MountTarget
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groups = null,Object? relay = null,}) {
  return _then(_MountTarget(
groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<MountGroupInfo>,relay: null == relay ? _self._relay : relay // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$MountNode {

 String get name; String get original;
/// Create a copy of MountNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountNodeCopyWith<MountNode> get copyWith => _$MountNodeCopyWithImpl<MountNode>(this as MountNode, _$identity);

  /// Serializes this MountNode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountNode;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountNode&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.original, _this.original) || other.original == _this.original));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountNode;
  return Object.hash(runtimeType,_this.name,_this.original);
}

@override
String toString() {
  final _this = this as MountNode;
  return 'MountNode(name: ${_this.name}, original: ${_this.original})';
}


}

/// @nodoc
abstract mixin class $MountNodeCopyWith<$Res>  {
  factory $MountNodeCopyWith(MountNode value, $Res Function(MountNode) _then) = _$MountNodeCopyWithImpl;
@useResult
$Res call({
 String name, String original
});




}
/// @nodoc
class _$MountNodeCopyWithImpl<$Res>
    implements $MountNodeCopyWith<$Res> {
  _$MountNodeCopyWithImpl(this._self, this._then);

  final MountNode _self;
  final $Res Function(MountNode) _then;

/// Create a copy of MountNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? original = null,}) {
  return _then(MountNode(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,original: null == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MountNode].
extension MountNodePatterns on MountNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountNode value)  $default,){
final _that = this;
switch (_that) {
case _MountNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountNode value)?  $default,){
final _that = this;
switch (_that) {
case _MountNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String original)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountNode() when $default != null:
return $default(_that.name,_that.original);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String original)  $default,) {final _that = this;
switch (_that) {
case _MountNode():
return $default(_that.name,_that.original);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String original)?  $default,) {final _that = this;
switch (_that) {
case _MountNode() when $default != null:
return $default(_that.name,_that.original);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountNode implements MountNode {
  const _MountNode({required this.name, required this.original});
  factory _MountNode.fromJson(Map<String, dynamic> json) => _$MountNodeFromJson(json);

@override final  String name;
@override final  String original;

/// Create a copy of MountNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountNodeCopyWith<_MountNode> get copyWith => __$MountNodeCopyWithImpl<_MountNode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountNodeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountNode&&(identical(other.name, name) || other.name == name)&&(identical(other.original, original) || other.original == original));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,original);
}

@override
String toString() {
    return 'MountNode(name: $name, original: $original)';
}


}

/// @nodoc
abstract mixin class _$MountNodeCopyWith<$Res> implements $MountNodeCopyWith<$Res> {
  factory _$MountNodeCopyWith(_MountNode value, $Res Function(_MountNode) _then) = __$MountNodeCopyWithImpl;
@override @useResult
$Res call({
 String name, String original
});




}
/// @nodoc
class __$MountNodeCopyWithImpl<$Res>
    implements _$MountNodeCopyWith<$Res> {
  __$MountNodeCopyWithImpl(this._self, this._then);

  final _MountNode _self;
  final $Res Function(_MountNode) _then;

/// Create a copy of MountNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? original = null,}) {
  return _then(_MountNode(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,original: null == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MountSourceReport {

 int get id; String get provider; MountSourceStatus get status;@JsonKey(name: 'tailscale-excluded') int get tailscaleExcluded;@JsonKey(name: 'relay-excluded') int get relayExcluded; List<MountNode> get nodes;
/// Create a copy of MountSourceReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountSourceReportCopyWith<MountSourceReport> get copyWith => _$MountSourceReportCopyWithImpl<MountSourceReport>(this as MountSourceReport, _$identity);

  /// Serializes this MountSourceReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountSourceReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountSourceReport&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.tailscaleExcluded, _this.tailscaleExcluded) || other.tailscaleExcluded == _this.tailscaleExcluded)&&(identical(other.relayExcluded, _this.relayExcluded) || other.relayExcluded == _this.relayExcluded)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountSourceReport;
  return Object.hash(runtimeType,_this.id,_this.provider,_this.status,_this.tailscaleExcluded,_this.relayExcluded,const DeepCollectionEquality().hash(_this.nodes));
}

@override
String toString() {
  final _this = this as MountSourceReport;
  return 'MountSourceReport(id: ${_this.id}, provider: ${_this.provider}, status: ${_this.status}, tailscaleExcluded: ${_this.tailscaleExcluded}, relayExcluded: ${_this.relayExcluded}, nodes: ${_this.nodes})';
}


}

/// @nodoc
abstract mixin class $MountSourceReportCopyWith<$Res>  {
  factory $MountSourceReportCopyWith(MountSourceReport value, $Res Function(MountSourceReport) _then) = _$MountSourceReportCopyWithImpl;
@useResult
$Res call({
 int id, String provider, MountSourceStatus status,@JsonKey(name: 'tailscale-excluded') int tailscaleExcluded,@JsonKey(name: 'relay-excluded') int relayExcluded, List<MountNode> nodes
});




}
/// @nodoc
class _$MountSourceReportCopyWithImpl<$Res>
    implements $MountSourceReportCopyWith<$Res> {
  _$MountSourceReportCopyWithImpl(this._self, this._then);

  final MountSourceReport _self;
  final $Res Function(MountSourceReport) _then;

/// Create a copy of MountSourceReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? provider = null,Object? status = null,Object? tailscaleExcluded = null,Object? relayExcluded = null,Object? nodes = null,}) {
  return _then(MountSourceReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MountSourceStatus,tailscaleExcluded: null == tailscaleExcluded ? _self.tailscaleExcluded : tailscaleExcluded // ignore: cast_nullable_to_non_nullable
as int,relayExcluded: null == relayExcluded ? _self.relayExcluded : relayExcluded // ignore: cast_nullable_to_non_nullable
as int,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<MountNode>,
  ));
}

}


/// Adds pattern-matching-related methods to [MountSourceReport].
extension MountSourceReportPatterns on MountSourceReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountSourceReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountSourceReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountSourceReport value)  $default,){
final _that = this;
switch (_that) {
case _MountSourceReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountSourceReport value)?  $default,){
final _that = this;
switch (_that) {
case _MountSourceReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String provider,  MountSourceStatus status, @JsonKey(name: 'tailscale-excluded')  int tailscaleExcluded, @JsonKey(name: 'relay-excluded')  int relayExcluded,  List<MountNode> nodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountSourceReport() when $default != null:
return $default(_that.id,_that.provider,_that.status,_that.tailscaleExcluded,_that.relayExcluded,_that.nodes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String provider,  MountSourceStatus status, @JsonKey(name: 'tailscale-excluded')  int tailscaleExcluded, @JsonKey(name: 'relay-excluded')  int relayExcluded,  List<MountNode> nodes)  $default,) {final _that = this;
switch (_that) {
case _MountSourceReport():
return $default(_that.id,_that.provider,_that.status,_that.tailscaleExcluded,_that.relayExcluded,_that.nodes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String provider,  MountSourceStatus status, @JsonKey(name: 'tailscale-excluded')  int tailscaleExcluded, @JsonKey(name: 'relay-excluded')  int relayExcluded,  List<MountNode> nodes)?  $default,) {final _that = this;
switch (_that) {
case _MountSourceReport() when $default != null:
return $default(_that.id,_that.provider,_that.status,_that.tailscaleExcluded,_that.relayExcluded,_that.nodes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountSourceReport implements MountSourceReport {
  const _MountSourceReport({required this.id, required this.provider, required this.status, @JsonKey(name: 'tailscale-excluded') this.tailscaleExcluded = 0, @JsonKey(name: 'relay-excluded') this.relayExcluded = 0,  List<MountNode> nodes = const []}): _nodes = nodes;
  factory _MountSourceReport.fromJson(Map<String, dynamic> json) => _$MountSourceReportFromJson(json);

@override final  int id;
@override final  String provider;
@override final  MountSourceStatus status;
@override@JsonKey(name: 'tailscale-excluded') final  int tailscaleExcluded;
@override@JsonKey(name: 'relay-excluded') final  int relayExcluded;
 final  List<MountNode> _nodes;
@override@JsonKey() List<MountNode> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of MountSourceReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountSourceReportCopyWith<_MountSourceReport> get copyWith => __$MountSourceReportCopyWithImpl<_MountSourceReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountSourceReportToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountSourceReport&&(identical(other.id, id) || other.id == id)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.status, status) || other.status == status)&&(identical(other.tailscaleExcluded, tailscaleExcluded) || other.tailscaleExcluded == tailscaleExcluded)&&(identical(other.relayExcluded, relayExcluded) || other.relayExcluded == relayExcluded)&&const DeepCollectionEquality().equals(other.nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,provider,status,tailscaleExcluded,relayExcluded,const DeepCollectionEquality().hash(_nodes));
}

@override
String toString() {
    return 'MountSourceReport(id: $id, provider: $provider, status: $status, tailscaleExcluded: $tailscaleExcluded, relayExcluded: $relayExcluded, nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$MountSourceReportCopyWith<$Res> implements $MountSourceReportCopyWith<$Res> {
  factory _$MountSourceReportCopyWith(_MountSourceReport value, $Res Function(_MountSourceReport) _then) = __$MountSourceReportCopyWithImpl;
@override @useResult
$Res call({
 int id, String provider, MountSourceStatus status,@JsonKey(name: 'tailscale-excluded') int tailscaleExcluded,@JsonKey(name: 'relay-excluded') int relayExcluded, List<MountNode> nodes
});




}
/// @nodoc
class __$MountSourceReportCopyWithImpl<$Res>
    implements _$MountSourceReportCopyWith<$Res> {
  __$MountSourceReportCopyWithImpl(this._self, this._then);

  final _MountSourceReport _self;
  final $Res Function(_MountSourceReport) _then;

/// Create a copy of MountSourceReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? provider = null,Object? status = null,Object? tailscaleExcluded = null,Object? relayExcluded = null,Object? nodes = null,}) {
  return _then(_MountSourceReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MountSourceStatus,tailscaleExcluded: null == tailscaleExcluded ? _self.tailscaleExcluded : tailscaleExcluded // ignore: cast_nullable_to_non_nullable
as int,relayExcluded: null == relayExcluded ? _self.relayExcluded : relayExcluded // ignore: cast_nullable_to_non_nullable
as int,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<MountNode>,
  ));
}


}


/// @nodoc
mixin _$MountGroupReport {

 String get name; MountGroupVia get via; MountProtection get protection;@JsonKey(name: 'empty-fallback') String get emptyFallback;
/// Create a copy of MountGroupReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountGroupReportCopyWith<MountGroupReport> get copyWith => _$MountGroupReportCopyWithImpl<MountGroupReport>(this as MountGroupReport, _$identity);

  /// Serializes this MountGroupReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountGroupReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountGroupReport&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.via, _this.via) || other.via == _this.via)&&(identical(other.protection, _this.protection) || other.protection == _this.protection)&&(identical(other.emptyFallback, _this.emptyFallback) || other.emptyFallback == _this.emptyFallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountGroupReport;
  return Object.hash(runtimeType,_this.name,_this.via,_this.protection,_this.emptyFallback);
}

@override
String toString() {
  final _this = this as MountGroupReport;
  return 'MountGroupReport(name: ${_this.name}, via: ${_this.via}, protection: ${_this.protection}, emptyFallback: ${_this.emptyFallback})';
}


}

/// @nodoc
abstract mixin class $MountGroupReportCopyWith<$Res>  {
  factory $MountGroupReportCopyWith(MountGroupReport value, $Res Function(MountGroupReport) _then) = _$MountGroupReportCopyWithImpl;
@useResult
$Res call({
 String name, MountGroupVia via, MountProtection protection,@JsonKey(name: 'empty-fallback') String emptyFallback
});




}
/// @nodoc
class _$MountGroupReportCopyWithImpl<$Res>
    implements $MountGroupReportCopyWith<$Res> {
  _$MountGroupReportCopyWithImpl(this._self, this._then);

  final MountGroupReport _self;
  final $Res Function(MountGroupReport) _then;

/// Create a copy of MountGroupReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? via = null,Object? protection = null,Object? emptyFallback = null,}) {
  return _then(MountGroupReport(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,via: null == via ? _self.via : via // ignore: cast_nullable_to_non_nullable
as MountGroupVia,protection: null == protection ? _self.protection : protection // ignore: cast_nullable_to_non_nullable
as MountProtection,emptyFallback: null == emptyFallback ? _self.emptyFallback : emptyFallback // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MountGroupReport].
extension MountGroupReportPatterns on MountGroupReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountGroupReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountGroupReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountGroupReport value)  $default,){
final _that = this;
switch (_that) {
case _MountGroupReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountGroupReport value)?  $default,){
final _that = this;
switch (_that) {
case _MountGroupReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  MountGroupVia via,  MountProtection protection, @JsonKey(name: 'empty-fallback')  String emptyFallback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountGroupReport() when $default != null:
return $default(_that.name,_that.via,_that.protection,_that.emptyFallback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  MountGroupVia via,  MountProtection protection, @JsonKey(name: 'empty-fallback')  String emptyFallback)  $default,) {final _that = this;
switch (_that) {
case _MountGroupReport():
return $default(_that.name,_that.via,_that.protection,_that.emptyFallback);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  MountGroupVia via,  MountProtection protection, @JsonKey(name: 'empty-fallback')  String emptyFallback)?  $default,) {final _that = this;
switch (_that) {
case _MountGroupReport() when $default != null:
return $default(_that.name,_that.via,_that.protection,_that.emptyFallback);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountGroupReport implements MountGroupReport {
  const _MountGroupReport({required this.name, required this.via, required this.protection, @JsonKey(name: 'empty-fallback') this.emptyFallback = ''});
  factory _MountGroupReport.fromJson(Map<String, dynamic> json) => _$MountGroupReportFromJson(json);

@override final  String name;
@override final  MountGroupVia via;
@override final  MountProtection protection;
@override@JsonKey(name: 'empty-fallback') final  String emptyFallback;

/// Create a copy of MountGroupReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountGroupReportCopyWith<_MountGroupReport> get copyWith => __$MountGroupReportCopyWithImpl<_MountGroupReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountGroupReportToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountGroupReport&&(identical(other.name, name) || other.name == name)&&(identical(other.via, via) || other.via == via)&&(identical(other.protection, protection) || other.protection == protection)&&(identical(other.emptyFallback, emptyFallback) || other.emptyFallback == emptyFallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,via,protection,emptyFallback);
}

@override
String toString() {
    return 'MountGroupReport(name: $name, via: $via, protection: $protection, emptyFallback: $emptyFallback)';
}


}

/// @nodoc
abstract mixin class _$MountGroupReportCopyWith<$Res> implements $MountGroupReportCopyWith<$Res> {
  factory _$MountGroupReportCopyWith(_MountGroupReport value, $Res Function(_MountGroupReport) _then) = __$MountGroupReportCopyWithImpl;
@override @useResult
$Res call({
 String name, MountGroupVia via, MountProtection protection,@JsonKey(name: 'empty-fallback') String emptyFallback
});




}
/// @nodoc
class __$MountGroupReportCopyWithImpl<$Res>
    implements _$MountGroupReportCopyWith<$Res> {
  __$MountGroupReportCopyWithImpl(this._self, this._then);

  final _MountGroupReport _self;
  final $Res Function(_MountGroupReport) _then;

/// Create a copy of MountGroupReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? via = null,Object? protection = null,Object? emptyFallback = null,}) {
  return _then(_MountGroupReport(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,via: null == via ? _self.via : via // ignore: cast_nullable_to_non_nullable
as MountGroupVia,protection: null == protection ? _self.protection : protection // ignore: cast_nullable_to_non_nullable
as MountProtection,emptyFallback: null == emptyFallback ? _self.emptyFallback : emptyFallback // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MountReport {

 int get target; String get revision; List<MountSourceReport> get sources; List<MountGroupReport> get groups; int get renamed;
/// Create a copy of MountReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountReportCopyWith<MountReport> get copyWith => _$MountReportCopyWithImpl<MountReport>(this as MountReport, _$identity);

  /// Serializes this MountReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountReport&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&const DeepCollectionEquality().equals(other.sources, _this.sources)&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&(identical(other.renamed, _this.renamed) || other.renamed == _this.renamed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountReport;
  return Object.hash(runtimeType,_this.target,_this.revision,const DeepCollectionEquality().hash(_this.sources),const DeepCollectionEquality().hash(_this.groups),_this.renamed);
}

@override
String toString() {
  final _this = this as MountReport;
  return 'MountReport(target: ${_this.target}, revision: ${_this.revision}, sources: ${_this.sources}, groups: ${_this.groups}, renamed: ${_this.renamed})';
}


}

/// @nodoc
abstract mixin class $MountReportCopyWith<$Res>  {
  factory $MountReportCopyWith(MountReport value, $Res Function(MountReport) _then) = _$MountReportCopyWithImpl;
@useResult
$Res call({
 int target, String revision, List<MountSourceReport> sources, List<MountGroupReport> groups, int renamed
});




}
/// @nodoc
class _$MountReportCopyWithImpl<$Res>
    implements $MountReportCopyWith<$Res> {
  _$MountReportCopyWithImpl(this._self, this._then);

  final MountReport _self;
  final $Res Function(MountReport) _then;

/// Create a copy of MountReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? revision = null,Object? sources = null,Object? groups = null,Object? renamed = null,}) {
  return _then(MountReport(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<MountSourceReport>,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<MountGroupReport>,renamed: null == renamed ? _self.renamed : renamed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MountReport].
extension MountReportPatterns on MountReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountReport value)  $default,){
final _that = this;
switch (_that) {
case _MountReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountReport value)?  $default,){
final _that = this;
switch (_that) {
case _MountReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int target,  String revision,  List<MountSourceReport> sources,  List<MountGroupReport> groups,  int renamed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountReport() when $default != null:
return $default(_that.target,_that.revision,_that.sources,_that.groups,_that.renamed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int target,  String revision,  List<MountSourceReport> sources,  List<MountGroupReport> groups,  int renamed)  $default,) {final _that = this;
switch (_that) {
case _MountReport():
return $default(_that.target,_that.revision,_that.sources,_that.groups,_that.renamed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int target,  String revision,  List<MountSourceReport> sources,  List<MountGroupReport> groups,  int renamed)?  $default,) {final _that = this;
switch (_that) {
case _MountReport() when $default != null:
return $default(_that.target,_that.revision,_that.sources,_that.groups,_that.renamed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountReport implements MountReport {
  const _MountReport({this.target = 0, this.revision = '',  List<MountSourceReport> sources = const [],  List<MountGroupReport> groups = const [], this.renamed = 0}): _sources = sources,_groups = groups;
  factory _MountReport.fromJson(Map<String, dynamic> json) => _$MountReportFromJson(json);

@override@JsonKey() final  int target;
@override@JsonKey() final  String revision;
 final  List<MountSourceReport> _sources;
@override@JsonKey() List<MountSourceReport> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}

 final  List<MountGroupReport> _groups;
@override@JsonKey() List<MountGroupReport> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

@override@JsonKey() final  int renamed;

/// Create a copy of MountReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountReportCopyWith<_MountReport> get copyWith => __$MountReportCopyWithImpl<_MountReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountReportToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountReport&&(identical(other.target, target) || other.target == target)&&(identical(other.revision, revision) || other.revision == revision)&&const DeepCollectionEquality().equals(other.sources, _sources)&&const DeepCollectionEquality().equals(other.groups, _groups)&&(identical(other.renamed, renamed) || other.renamed == renamed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,target,revision,const DeepCollectionEquality().hash(_sources),const DeepCollectionEquality().hash(_groups),renamed);
}

@override
String toString() {
    return 'MountReport(target: $target, revision: $revision, sources: $sources, groups: $groups, renamed: $renamed)';
}


}

/// @nodoc
abstract mixin class _$MountReportCopyWith<$Res> implements $MountReportCopyWith<$Res> {
  factory _$MountReportCopyWith(_MountReport value, $Res Function(_MountReport) _then) = __$MountReportCopyWithImpl;
@override @useResult
$Res call({
 int target, String revision, List<MountSourceReport> sources, List<MountGroupReport> groups, int renamed
});




}
/// @nodoc
class __$MountReportCopyWithImpl<$Res>
    implements _$MountReportCopyWith<$Res> {
  __$MountReportCopyWithImpl(this._self, this._then);

  final _MountReport _self;
  final $Res Function(_MountReport) _then;

/// Create a copy of MountReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? revision = null,Object? sources = null,Object? groups = null,Object? renamed = null,}) {
  return _then(_MountReport(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<MountSourceReport>,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<MountGroupReport>,renamed: null == renamed ? _self.renamed : renamed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$MountPreflight {

 String? get error;@JsonKey(name: 'error-code') String? get errorCode; MountReport? get report;
/// Create a copy of MountPreflight
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountPreflightCopyWith<MountPreflight> get copyWith => _$MountPreflightCopyWithImpl<MountPreflight>(this as MountPreflight, _$identity);

  /// Serializes this MountPreflight to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountPreflight;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountPreflight&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.errorCode, _this.errorCode) || other.errorCode == _this.errorCode)&&(identical(other.report, _this.report) || other.report == _this.report));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountPreflight;
  return Object.hash(runtimeType,_this.error,_this.errorCode,_this.report);
}

@override
String toString() {
  final _this = this as MountPreflight;
  return 'MountPreflight(error: ${_this.error}, errorCode: ${_this.errorCode}, report: ${_this.report})';
}


}

/// @nodoc
abstract mixin class $MountPreflightCopyWith<$Res>  {
  factory $MountPreflightCopyWith(MountPreflight value, $Res Function(MountPreflight) _then) = _$MountPreflightCopyWithImpl;
@useResult
$Res call({
 String? error,@JsonKey(name: 'error-code') String? errorCode, MountReport? report
});


$MountReportCopyWith<$Res>? get report;

}
/// @nodoc
class _$MountPreflightCopyWithImpl<$Res>
    implements $MountPreflightCopyWith<$Res> {
  _$MountPreflightCopyWithImpl(this._self, this._then);

  final MountPreflight _self;
  final $Res Function(MountPreflight) _then;

/// Create a copy of MountPreflight
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? error = freezed,Object? errorCode = freezed,Object? report = freezed,}) {
  return _then(MountPreflight(
error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,report: freezed == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as MountReport?,
  ));
}
/// Create a copy of MountPreflight
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountReportCopyWith<$Res>? get report {
    if (_self.report == null) {
    return null;
  }

  return $MountReportCopyWith<$Res>(_self.report!, (value) {
    return _then(_self.copyWith(report: value));
  });
}
}


/// Adds pattern-matching-related methods to [MountPreflight].
extension MountPreflightPatterns on MountPreflight {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountPreflight value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountPreflight() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountPreflight value)  $default,){
final _that = this;
switch (_that) {
case _MountPreflight():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountPreflight value)?  $default,){
final _that = this;
switch (_that) {
case _MountPreflight() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? error, @JsonKey(name: 'error-code')  String? errorCode,  MountReport? report)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountPreflight() when $default != null:
return $default(_that.error,_that.errorCode,_that.report);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? error, @JsonKey(name: 'error-code')  String? errorCode,  MountReport? report)  $default,) {final _that = this;
switch (_that) {
case _MountPreflight():
return $default(_that.error,_that.errorCode,_that.report);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? error, @JsonKey(name: 'error-code')  String? errorCode,  MountReport? report)?  $default,) {final _that = this;
switch (_that) {
case _MountPreflight() when $default != null:
return $default(_that.error,_that.errorCode,_that.report);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountPreflight implements MountPreflight {
  const _MountPreflight({this.error, @JsonKey(name: 'error-code') this.errorCode, this.report});
  factory _MountPreflight.fromJson(Map<String, dynamic> json) => _$MountPreflightFromJson(json);

@override final  String? error;
@override@JsonKey(name: 'error-code') final  String? errorCode;
@override final  MountReport? report;

/// Create a copy of MountPreflight
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountPreflightCopyWith<_MountPreflight> get copyWith => __$MountPreflightCopyWithImpl<_MountPreflight>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountPreflightToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountPreflight&&(identical(other.error, error) || other.error == error)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.report, report) || other.report == report));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,error,errorCode,report);
}

@override
String toString() {
    return 'MountPreflight(error: $error, errorCode: $errorCode, report: $report)';
}


}

/// @nodoc
abstract mixin class _$MountPreflightCopyWith<$Res> implements $MountPreflightCopyWith<$Res> {
  factory _$MountPreflightCopyWith(_MountPreflight value, $Res Function(_MountPreflight) _then) = __$MountPreflightCopyWithImpl;
@override @useResult
$Res call({
 String? error,@JsonKey(name: 'error-code') String? errorCode, MountReport? report
});


@override $MountReportCopyWith<$Res>? get report;

}
/// @nodoc
class __$MountPreflightCopyWithImpl<$Res>
    implements _$MountPreflightCopyWith<$Res> {
  __$MountPreflightCopyWithImpl(this._self, this._then);

  final _MountPreflight _self;
  final $Res Function(_MountPreflight) _then;

/// Create a copy of MountPreflight
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? error = freezed,Object? errorCode = freezed,Object? report = freezed,}) {
  return _then(_MountPreflight(
error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,report: freezed == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as MountReport?,
  ));
}

/// Create a copy of MountPreflight
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountReportCopyWith<$Res>? get report {
    if (_self.report == null) {
    return null;
  }

  return $MountReportCopyWith<$Res>(_self.report!, (value) {
    return _then(_self.copyWith(report: value));
  });
}
}


/// @nodoc
mixin _$MountRuntimeSource {

 int get id; String get provider; bool get present; int get count; bool get matches;
/// Create a copy of MountRuntimeSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountRuntimeSourceCopyWith<MountRuntimeSource> get copyWith => _$MountRuntimeSourceCopyWithImpl<MountRuntimeSource>(this as MountRuntimeSource, _$identity);

  /// Serializes this MountRuntimeSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountRuntimeSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountRuntimeSource&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.present, _this.present) || other.present == _this.present)&&(identical(other.count, _this.count) || other.count == _this.count)&&(identical(other.matches, _this.matches) || other.matches == _this.matches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountRuntimeSource;
  return Object.hash(runtimeType,_this.id,_this.provider,_this.present,_this.count,_this.matches);
}

@override
String toString() {
  final _this = this as MountRuntimeSource;
  return 'MountRuntimeSource(id: ${_this.id}, provider: ${_this.provider}, present: ${_this.present}, count: ${_this.count}, matches: ${_this.matches})';
}


}

/// @nodoc
abstract mixin class $MountRuntimeSourceCopyWith<$Res>  {
  factory $MountRuntimeSourceCopyWith(MountRuntimeSource value, $Res Function(MountRuntimeSource) _then) = _$MountRuntimeSourceCopyWithImpl;
@useResult
$Res call({
 int id, String provider, bool present, int count, bool matches
});




}
/// @nodoc
class _$MountRuntimeSourceCopyWithImpl<$Res>
    implements $MountRuntimeSourceCopyWith<$Res> {
  _$MountRuntimeSourceCopyWithImpl(this._self, this._then);

  final MountRuntimeSource _self;
  final $Res Function(MountRuntimeSource) _then;

/// Create a copy of MountRuntimeSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? provider = null,Object? present = null,Object? count = null,Object? matches = null,}) {
  return _then(MountRuntimeSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as bool,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,matches: null == matches ? _self.matches : matches // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MountRuntimeSource].
extension MountRuntimeSourcePatterns on MountRuntimeSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountRuntimeSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountRuntimeSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountRuntimeSource value)  $default,){
final _that = this;
switch (_that) {
case _MountRuntimeSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountRuntimeSource value)?  $default,){
final _that = this;
switch (_that) {
case _MountRuntimeSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String provider,  bool present,  int count,  bool matches)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountRuntimeSource() when $default != null:
return $default(_that.id,_that.provider,_that.present,_that.count,_that.matches);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String provider,  bool present,  int count,  bool matches)  $default,) {final _that = this;
switch (_that) {
case _MountRuntimeSource():
return $default(_that.id,_that.provider,_that.present,_that.count,_that.matches);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String provider,  bool present,  int count,  bool matches)?  $default,) {final _that = this;
switch (_that) {
case _MountRuntimeSource() when $default != null:
return $default(_that.id,_that.provider,_that.present,_that.count,_that.matches);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountRuntimeSource implements MountRuntimeSource {
  const _MountRuntimeSource({required this.id, required this.provider, this.present = false, this.count = 0, this.matches = false});
  factory _MountRuntimeSource.fromJson(Map<String, dynamic> json) => _$MountRuntimeSourceFromJson(json);

@override final  int id;
@override final  String provider;
@override@JsonKey() final  bool present;
@override@JsonKey() final  int count;
@override@JsonKey() final  bool matches;

/// Create a copy of MountRuntimeSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountRuntimeSourceCopyWith<_MountRuntimeSource> get copyWith => __$MountRuntimeSourceCopyWithImpl<_MountRuntimeSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountRuntimeSourceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountRuntimeSource&&(identical(other.id, id) || other.id == id)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.present, present) || other.present == present)&&(identical(other.count, count) || other.count == count)&&(identical(other.matches, matches) || other.matches == matches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,provider,present,count,matches);
}

@override
String toString() {
    return 'MountRuntimeSource(id: $id, provider: $provider, present: $present, count: $count, matches: $matches)';
}


}

/// @nodoc
abstract mixin class _$MountRuntimeSourceCopyWith<$Res> implements $MountRuntimeSourceCopyWith<$Res> {
  factory _$MountRuntimeSourceCopyWith(_MountRuntimeSource value, $Res Function(_MountRuntimeSource) _then) = __$MountRuntimeSourceCopyWithImpl;
@override @useResult
$Res call({
 int id, String provider, bool present, int count, bool matches
});




}
/// @nodoc
class __$MountRuntimeSourceCopyWithImpl<$Res>
    implements _$MountRuntimeSourceCopyWith<$Res> {
  __$MountRuntimeSourceCopyWithImpl(this._self, this._then);

  final _MountRuntimeSource _self;
  final $Res Function(_MountRuntimeSource) _then;

/// Create a copy of MountRuntimeSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? provider = null,Object? present = null,Object? count = null,Object? matches = null,}) {
  return _then(_MountRuntimeSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as bool,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,matches: null == matches ? _self.matches : matches // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$MountRuntimeGroup {

 String get name; bool get present; int get members; int get mounted; bool get empty; String? get fallback;
/// Create a copy of MountRuntimeGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountRuntimeGroupCopyWith<MountRuntimeGroup> get copyWith => _$MountRuntimeGroupCopyWithImpl<MountRuntimeGroup>(this as MountRuntimeGroup, _$identity);

  /// Serializes this MountRuntimeGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountRuntimeGroup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountRuntimeGroup&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.present, _this.present) || other.present == _this.present)&&(identical(other.members, _this.members) || other.members == _this.members)&&(identical(other.mounted, _this.mounted) || other.mounted == _this.mounted)&&(identical(other.empty, _this.empty) || other.empty == _this.empty)&&(identical(other.fallback, _this.fallback) || other.fallback == _this.fallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountRuntimeGroup;
  return Object.hash(runtimeType,_this.name,_this.present,_this.members,_this.mounted,_this.empty,_this.fallback);
}

@override
String toString() {
  final _this = this as MountRuntimeGroup;
  return 'MountRuntimeGroup(name: ${_this.name}, present: ${_this.present}, members: ${_this.members}, mounted: ${_this.mounted}, empty: ${_this.empty}, fallback: ${_this.fallback})';
}


}

/// @nodoc
abstract mixin class $MountRuntimeGroupCopyWith<$Res>  {
  factory $MountRuntimeGroupCopyWith(MountRuntimeGroup value, $Res Function(MountRuntimeGroup) _then) = _$MountRuntimeGroupCopyWithImpl;
@useResult
$Res call({
 String name, bool present, int members, int mounted, bool empty, String? fallback
});




}
/// @nodoc
class _$MountRuntimeGroupCopyWithImpl<$Res>
    implements $MountRuntimeGroupCopyWith<$Res> {
  _$MountRuntimeGroupCopyWithImpl(this._self, this._then);

  final MountRuntimeGroup _self;
  final $Res Function(MountRuntimeGroup) _then;

/// Create a copy of MountRuntimeGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? present = null,Object? members = null,Object? mounted = null,Object? empty = null,Object? fallback = freezed,}) {
  return _then(MountRuntimeGroup(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as bool,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as int,mounted: null == mounted ? _self.mounted : mounted // ignore: cast_nullable_to_non_nullable
as int,empty: null == empty ? _self.empty : empty // ignore: cast_nullable_to_non_nullable
as bool,fallback: freezed == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MountRuntimeGroup].
extension MountRuntimeGroupPatterns on MountRuntimeGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountRuntimeGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountRuntimeGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountRuntimeGroup value)  $default,){
final _that = this;
switch (_that) {
case _MountRuntimeGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountRuntimeGroup value)?  $default,){
final _that = this;
switch (_that) {
case _MountRuntimeGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  bool present,  int members,  int mounted,  bool empty,  String? fallback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountRuntimeGroup() when $default != null:
return $default(_that.name,_that.present,_that.members,_that.mounted,_that.empty,_that.fallback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  bool present,  int members,  int mounted,  bool empty,  String? fallback)  $default,) {final _that = this;
switch (_that) {
case _MountRuntimeGroup():
return $default(_that.name,_that.present,_that.members,_that.mounted,_that.empty,_that.fallback);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  bool present,  int members,  int mounted,  bool empty,  String? fallback)?  $default,) {final _that = this;
switch (_that) {
case _MountRuntimeGroup() when $default != null:
return $default(_that.name,_that.present,_that.members,_that.mounted,_that.empty,_that.fallback);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountRuntimeGroup implements MountRuntimeGroup {
  const _MountRuntimeGroup({required this.name, this.present = false, this.members = 0, this.mounted = 0, this.empty = false, this.fallback});
  factory _MountRuntimeGroup.fromJson(Map<String, dynamic> json) => _$MountRuntimeGroupFromJson(json);

@override final  String name;
@override@JsonKey() final  bool present;
@override@JsonKey() final  int members;
@override@JsonKey() final  int mounted;
@override@JsonKey() final  bool empty;
@override final  String? fallback;

/// Create a copy of MountRuntimeGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountRuntimeGroupCopyWith<_MountRuntimeGroup> get copyWith => __$MountRuntimeGroupCopyWithImpl<_MountRuntimeGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountRuntimeGroupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountRuntimeGroup&&(identical(other.name, name) || other.name == name)&&(identical(other.present, present) || other.present == present)&&(identical(other.members, members) || other.members == members)&&(identical(other.mounted, mounted) || other.mounted == mounted)&&(identical(other.empty, empty) || other.empty == empty)&&(identical(other.fallback, fallback) || other.fallback == fallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,present,members,mounted,empty,fallback);
}

@override
String toString() {
    return 'MountRuntimeGroup(name: $name, present: $present, members: $members, mounted: $mounted, empty: $empty, fallback: $fallback)';
}


}

/// @nodoc
abstract mixin class _$MountRuntimeGroupCopyWith<$Res> implements $MountRuntimeGroupCopyWith<$Res> {
  factory _$MountRuntimeGroupCopyWith(_MountRuntimeGroup value, $Res Function(_MountRuntimeGroup) _then) = __$MountRuntimeGroupCopyWithImpl;
@override @useResult
$Res call({
 String name, bool present, int members, int mounted, bool empty, String? fallback
});




}
/// @nodoc
class __$MountRuntimeGroupCopyWithImpl<$Res>
    implements _$MountRuntimeGroupCopyWith<$Res> {
  __$MountRuntimeGroupCopyWithImpl(this._self, this._then);

  final _MountRuntimeGroup _self;
  final $Res Function(_MountRuntimeGroup) _then;

/// Create a copy of MountRuntimeGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? present = null,Object? members = null,Object? mounted = null,Object? empty = null,Object? fallback = freezed,}) {
  return _then(_MountRuntimeGroup(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as bool,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as int,mounted: null == mounted ? _self.mounted : mounted // ignore: cast_nullable_to_non_nullable
as int,empty: null == empty ? _self.empty : empty // ignore: cast_nullable_to_non_nullable
as bool,fallback: freezed == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MountRuntimeState {

 bool get blocked; MountReport? get report; List<MountRuntimeSource> get sources; List<MountRuntimeGroup> get groups; Map<String, String> get moved; List<String> get lost;
/// Create a copy of MountRuntimeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountRuntimeStateCopyWith<MountRuntimeState> get copyWith => _$MountRuntimeStateCopyWithImpl<MountRuntimeState>(this as MountRuntimeState, _$identity);

  /// Serializes this MountRuntimeState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MountRuntimeState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountRuntimeState&&(identical(other.blocked, _this.blocked) || other.blocked == _this.blocked)&&(identical(other.report, _this.report) || other.report == _this.report)&&const DeepCollectionEquality().equals(other.sources, _this.sources)&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&const DeepCollectionEquality().equals(other.moved, _this.moved)&&const DeepCollectionEquality().equals(other.lost, _this.lost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MountRuntimeState;
  return Object.hash(runtimeType,_this.blocked,_this.report,const DeepCollectionEquality().hash(_this.sources),const DeepCollectionEquality().hash(_this.groups),const DeepCollectionEquality().hash(_this.moved),const DeepCollectionEquality().hash(_this.lost));
}

@override
String toString() {
  final _this = this as MountRuntimeState;
  return 'MountRuntimeState(blocked: ${_this.blocked}, report: ${_this.report}, sources: ${_this.sources}, groups: ${_this.groups}, moved: ${_this.moved}, lost: ${_this.lost})';
}


}

/// @nodoc
abstract mixin class $MountRuntimeStateCopyWith<$Res>  {
  factory $MountRuntimeStateCopyWith(MountRuntimeState value, $Res Function(MountRuntimeState) _then) = _$MountRuntimeStateCopyWithImpl;
@useResult
$Res call({
 bool blocked, MountReport? report, List<MountRuntimeSource> sources, List<MountRuntimeGroup> groups, Map<String, String> moved, List<String> lost
});


$MountReportCopyWith<$Res>? get report;

}
/// @nodoc
class _$MountRuntimeStateCopyWithImpl<$Res>
    implements $MountRuntimeStateCopyWith<$Res> {
  _$MountRuntimeStateCopyWithImpl(this._self, this._then);

  final MountRuntimeState _self;
  final $Res Function(MountRuntimeState) _then;

/// Create a copy of MountRuntimeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? blocked = null,Object? report = freezed,Object? sources = null,Object? groups = null,Object? moved = null,Object? lost = null,}) {
  return _then(MountRuntimeState(
blocked: null == blocked ? _self.blocked : blocked // ignore: cast_nullable_to_non_nullable
as bool,report: freezed == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as MountReport?,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<MountRuntimeSource>,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<MountRuntimeGroup>,moved: null == moved ? _self.moved : moved // ignore: cast_nullable_to_non_nullable
as Map<String, String>,lost: null == lost ? _self.lost : lost // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of MountRuntimeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountReportCopyWith<$Res>? get report {
    if (_self.report == null) {
    return null;
  }

  return $MountReportCopyWith<$Res>(_self.report!, (value) {
    return _then(_self.copyWith(report: value));
  });
}
}


/// Adds pattern-matching-related methods to [MountRuntimeState].
extension MountRuntimeStatePatterns on MountRuntimeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountRuntimeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountRuntimeState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountRuntimeState value)  $default,){
final _that = this;
switch (_that) {
case _MountRuntimeState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountRuntimeState value)?  $default,){
final _that = this;
switch (_that) {
case _MountRuntimeState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool blocked,  MountReport? report,  List<MountRuntimeSource> sources,  List<MountRuntimeGroup> groups,  Map<String, String> moved,  List<String> lost)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountRuntimeState() when $default != null:
return $default(_that.blocked,_that.report,_that.sources,_that.groups,_that.moved,_that.lost);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool blocked,  MountReport? report,  List<MountRuntimeSource> sources,  List<MountRuntimeGroup> groups,  Map<String, String> moved,  List<String> lost)  $default,) {final _that = this;
switch (_that) {
case _MountRuntimeState():
return $default(_that.blocked,_that.report,_that.sources,_that.groups,_that.moved,_that.lost);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool blocked,  MountReport? report,  List<MountRuntimeSource> sources,  List<MountRuntimeGroup> groups,  Map<String, String> moved,  List<String> lost)?  $default,) {final _that = this;
switch (_that) {
case _MountRuntimeState() when $default != null:
return $default(_that.blocked,_that.report,_that.sources,_that.groups,_that.moved,_that.lost);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MountRuntimeState implements MountRuntimeState {
  const _MountRuntimeState({this.blocked = false, this.report,  List<MountRuntimeSource> sources = const [],  List<MountRuntimeGroup> groups = const [],  Map<String, String> moved = const {},  List<String> lost = const []}): _sources = sources,_groups = groups,_moved = moved,_lost = lost;
  factory _MountRuntimeState.fromJson(Map<String, dynamic> json) => _$MountRuntimeStateFromJson(json);

@override@JsonKey() final  bool blocked;
@override final  MountReport? report;
 final  List<MountRuntimeSource> _sources;
@override@JsonKey() List<MountRuntimeSource> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}

 final  List<MountRuntimeGroup> _groups;
@override@JsonKey() List<MountRuntimeGroup> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

 final  Map<String, String> _moved;
@override@JsonKey() Map<String, String> get moved {
  if (_moved is EqualUnmodifiableMapView) return _moved;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_moved);
}

 final  List<String> _lost;
@override@JsonKey() List<String> get lost {
  if (_lost is EqualUnmodifiableListView) return _lost;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lost);
}


/// Create a copy of MountRuntimeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountRuntimeStateCopyWith<_MountRuntimeState> get copyWith => __$MountRuntimeStateCopyWithImpl<_MountRuntimeState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MountRuntimeStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountRuntimeState&&(identical(other.blocked, blocked) || other.blocked == blocked)&&(identical(other.report, report) || other.report == report)&&const DeepCollectionEquality().equals(other.sources, _sources)&&const DeepCollectionEquality().equals(other.groups, _groups)&&const DeepCollectionEquality().equals(other.moved, _moved)&&const DeepCollectionEquality().equals(other.lost, _lost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,blocked,report,const DeepCollectionEquality().hash(_sources),const DeepCollectionEquality().hash(_groups),const DeepCollectionEquality().hash(_moved),const DeepCollectionEquality().hash(_lost));
}

@override
String toString() {
    return 'MountRuntimeState(blocked: $blocked, report: $report, sources: $sources, groups: $groups, moved: $moved, lost: $lost)';
}


}

/// @nodoc
abstract mixin class _$MountRuntimeStateCopyWith<$Res> implements $MountRuntimeStateCopyWith<$Res> {
  factory _$MountRuntimeStateCopyWith(_MountRuntimeState value, $Res Function(_MountRuntimeState) _then) = __$MountRuntimeStateCopyWithImpl;
@override @useResult
$Res call({
 bool blocked, MountReport? report, List<MountRuntimeSource> sources, List<MountRuntimeGroup> groups, Map<String, String> moved, List<String> lost
});


@override $MountReportCopyWith<$Res>? get report;

}
/// @nodoc
class __$MountRuntimeStateCopyWithImpl<$Res>
    implements _$MountRuntimeStateCopyWith<$Res> {
  __$MountRuntimeStateCopyWithImpl(this._self, this._then);

  final _MountRuntimeState _self;
  final $Res Function(_MountRuntimeState) _then;

/// Create a copy of MountRuntimeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? blocked = null,Object? report = freezed,Object? sources = null,Object? groups = null,Object? moved = null,Object? lost = null,}) {
  return _then(_MountRuntimeState(
blocked: null == blocked ? _self.blocked : blocked // ignore: cast_nullable_to_non_nullable
as bool,report: freezed == report ? _self.report : report // ignore: cast_nullable_to_non_nullable
as MountReport?,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<MountRuntimeSource>,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<MountRuntimeGroup>,moved: null == moved ? _self._moved : moved // ignore: cast_nullable_to_non_nullable
as Map<String, String>,lost: null == lost ? _self._lost : lost // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of MountRuntimeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountReportCopyWith<$Res>? get report {
    if (_self.report == null) {
    return null;
  }

  return $MountReportCopyWith<$Res>(_self.report!, (value) {
    return _then(_self.copyWith(report: value));
  });
}
}

/// @nodoc
mixin _$MountSourceItem {

 Profile get profile; MountSourceState get state; int get count; int get tailscaleExcluded; int get relayExcluded; bool get mounted; MountSourceRecord? get record;
/// Create a copy of MountSourceItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountSourceItemCopyWith<MountSourceItem> get copyWith => _$MountSourceItemCopyWithImpl<MountSourceItem>(this as MountSourceItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MountSourceItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountSourceItem&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.count, _this.count) || other.count == _this.count)&&(identical(other.tailscaleExcluded, _this.tailscaleExcluded) || other.tailscaleExcluded == _this.tailscaleExcluded)&&(identical(other.relayExcluded, _this.relayExcluded) || other.relayExcluded == _this.relayExcluded)&&(identical(other.mounted, _this.mounted) || other.mounted == _this.mounted)&&(identical(other.record, _this.record) || other.record == _this.record));
}


@override
int get hashCode {
  final _this = this as MountSourceItem;
  return Object.hash(runtimeType,_this.profile,_this.state,_this.count,_this.tailscaleExcluded,_this.relayExcluded,_this.mounted,_this.record);
}

@override
String toString() {
  final _this = this as MountSourceItem;
  return 'MountSourceItem(profile: ${_this.profile}, state: ${_this.state}, count: ${_this.count}, tailscaleExcluded: ${_this.tailscaleExcluded}, relayExcluded: ${_this.relayExcluded}, mounted: ${_this.mounted}, record: ${_this.record})';
}


}

/// @nodoc
abstract mixin class $MountSourceItemCopyWith<$Res>  {
  factory $MountSourceItemCopyWith(MountSourceItem value, $Res Function(MountSourceItem) _then) = _$MountSourceItemCopyWithImpl;
@useResult
$Res call({
 Profile profile, MountSourceState state, int count, int tailscaleExcluded, int relayExcluded, bool mounted, MountSourceRecord? record
});


$ProfileCopyWith<$Res> get profile;$MountSourceRecordCopyWith<$Res>? get record;

}
/// @nodoc
class _$MountSourceItemCopyWithImpl<$Res>
    implements $MountSourceItemCopyWith<$Res> {
  _$MountSourceItemCopyWithImpl(this._self, this._then);

  final MountSourceItem _self;
  final $Res Function(MountSourceItem) _then;

/// Create a copy of MountSourceItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profile = null,Object? state = null,Object? count = null,Object? tailscaleExcluded = null,Object? relayExcluded = null,Object? mounted = null,Object? record = freezed,}) {
  return _then(MountSourceItem(
profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as Profile,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as MountSourceState,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,tailscaleExcluded: null == tailscaleExcluded ? _self.tailscaleExcluded : tailscaleExcluded // ignore: cast_nullable_to_non_nullable
as int,relayExcluded: null == relayExcluded ? _self.relayExcluded : relayExcluded // ignore: cast_nullable_to_non_nullable
as int,mounted: null == mounted ? _self.mounted : mounted // ignore: cast_nullable_to_non_nullable
as bool,record: freezed == record ? _self.record : record // ignore: cast_nullable_to_non_nullable
as MountSourceRecord?,
  ));
}
/// Create a copy of MountSourceItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCopyWith<$Res> get profile {
  
  return $ProfileCopyWith<$Res>(_self.profile, (value) {
    return _then(_self.copyWith(profile: value));
  });
}/// Create a copy of MountSourceItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountSourceRecordCopyWith<$Res>? get record {
    if (_self.record == null) {
    return null;
  }

  return $MountSourceRecordCopyWith<$Res>(_self.record!, (value) {
    return _then(_self.copyWith(record: value));
  });
}
}


/// Adds pattern-matching-related methods to [MountSourceItem].
extension MountSourceItemPatterns on MountSourceItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountSourceItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountSourceItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountSourceItem value)  $default,){
final _that = this;
switch (_that) {
case _MountSourceItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountSourceItem value)?  $default,){
final _that = this;
switch (_that) {
case _MountSourceItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Profile profile,  MountSourceState state,  int count,  int tailscaleExcluded,  int relayExcluded,  bool mounted,  MountSourceRecord? record)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountSourceItem() when $default != null:
return $default(_that.profile,_that.state,_that.count,_that.tailscaleExcluded,_that.relayExcluded,_that.mounted,_that.record);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Profile profile,  MountSourceState state,  int count,  int tailscaleExcluded,  int relayExcluded,  bool mounted,  MountSourceRecord? record)  $default,) {final _that = this;
switch (_that) {
case _MountSourceItem():
return $default(_that.profile,_that.state,_that.count,_that.tailscaleExcluded,_that.relayExcluded,_that.mounted,_that.record);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Profile profile,  MountSourceState state,  int count,  int tailscaleExcluded,  int relayExcluded,  bool mounted,  MountSourceRecord? record)?  $default,) {final _that = this;
switch (_that) {
case _MountSourceItem() when $default != null:
return $default(_that.profile,_that.state,_that.count,_that.tailscaleExcluded,_that.relayExcluded,_that.mounted,_that.record);case _:
  return null;

}
}

}

/// @nodoc


class _MountSourceItem implements MountSourceItem {
  const _MountSourceItem({required this.profile, required this.state, this.count = 0, this.tailscaleExcluded = 0, this.relayExcluded = 0, this.mounted = false, this.record});
  

@override final  Profile profile;
@override final  MountSourceState state;
@override@JsonKey() final  int count;
@override@JsonKey() final  int tailscaleExcluded;
@override@JsonKey() final  int relayExcluded;
@override@JsonKey() final  bool mounted;
@override final  MountSourceRecord? record;

/// Create a copy of MountSourceItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountSourceItemCopyWith<_MountSourceItem> get copyWith => __$MountSourceItemCopyWithImpl<_MountSourceItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountSourceItem&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.state, state) || other.state == state)&&(identical(other.count, count) || other.count == count)&&(identical(other.tailscaleExcluded, tailscaleExcluded) || other.tailscaleExcluded == tailscaleExcluded)&&(identical(other.relayExcluded, relayExcluded) || other.relayExcluded == relayExcluded)&&(identical(other.mounted, mounted) || other.mounted == mounted)&&(identical(other.record, record) || other.record == record));
}


@override
int get hashCode {
    return Object.hash(runtimeType,profile,state,count,tailscaleExcluded,relayExcluded,mounted,record);
}

@override
String toString() {
    return 'MountSourceItem(profile: $profile, state: $state, count: $count, tailscaleExcluded: $tailscaleExcluded, relayExcluded: $relayExcluded, mounted: $mounted, record: $record)';
}


}

/// @nodoc
abstract mixin class _$MountSourceItemCopyWith<$Res> implements $MountSourceItemCopyWith<$Res> {
  factory _$MountSourceItemCopyWith(_MountSourceItem value, $Res Function(_MountSourceItem) _then) = __$MountSourceItemCopyWithImpl;
@override @useResult
$Res call({
 Profile profile, MountSourceState state, int count, int tailscaleExcluded, int relayExcluded, bool mounted, MountSourceRecord? record
});


@override $ProfileCopyWith<$Res> get profile;@override $MountSourceRecordCopyWith<$Res>? get record;

}
/// @nodoc
class __$MountSourceItemCopyWithImpl<$Res>
    implements _$MountSourceItemCopyWith<$Res> {
  __$MountSourceItemCopyWithImpl(this._self, this._then);

  final _MountSourceItem _self;
  final $Res Function(_MountSourceItem) _then;

/// Create a copy of MountSourceItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profile = null,Object? state = null,Object? count = null,Object? tailscaleExcluded = null,Object? relayExcluded = null,Object? mounted = null,Object? record = freezed,}) {
  return _then(_MountSourceItem(
profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as Profile,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as MountSourceState,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,tailscaleExcluded: null == tailscaleExcluded ? _self.tailscaleExcluded : tailscaleExcluded // ignore: cast_nullable_to_non_nullable
as int,relayExcluded: null == relayExcluded ? _self.relayExcluded : relayExcluded // ignore: cast_nullable_to_non_nullable
as int,mounted: null == mounted ? _self.mounted : mounted // ignore: cast_nullable_to_non_nullable
as bool,record: freezed == record ? _self.record : record // ignore: cast_nullable_to_non_nullable
as MountSourceRecord?,
  ));
}

/// Create a copy of MountSourceItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCopyWith<$Res> get profile {
  
  return $ProfileCopyWith<$Res>(_self.profile, (value) {
    return _then(_self.copyWith(profile: value));
  });
}/// Create a copy of MountSourceItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountSourceRecordCopyWith<$Res>? get record {
    if (_self.record == null) {
    return null;
  }

  return $MountSourceRecordCopyWith<$Res>(_self.record!, (value) {
    return _then(_self.copyWith(record: value));
  });
}
}

/// @nodoc
mixin _$MountPanel {

 Profile get target; MountTargetState? get stored; List<MountSourceItem> get sources; MountTarget? get groups;
/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountPanelCopyWith<MountPanel> get copyWith => _$MountPanelCopyWithImpl<MountPanel>(this as MountPanel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MountPanel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountPanel&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.stored, _this.stored) || other.stored == _this.stored)&&const DeepCollectionEquality().equals(other.sources, _this.sources)&&(identical(other.groups, _this.groups) || other.groups == _this.groups));
}


@override
int get hashCode {
  final _this = this as MountPanel;
  return Object.hash(runtimeType,_this.target,_this.stored,const DeepCollectionEquality().hash(_this.sources),_this.groups);
}

@override
String toString() {
  final _this = this as MountPanel;
  return 'MountPanel(target: ${_this.target}, stored: ${_this.stored}, sources: ${_this.sources}, groups: ${_this.groups})';
}


}

/// @nodoc
abstract mixin class $MountPanelCopyWith<$Res>  {
  factory $MountPanelCopyWith(MountPanel value, $Res Function(MountPanel) _then) = _$MountPanelCopyWithImpl;
@useResult
$Res call({
 Profile target, MountTargetState? stored, List<MountSourceItem> sources, MountTarget? groups
});


$ProfileCopyWith<$Res> get target;$MountTargetStateCopyWith<$Res>? get stored;$MountTargetCopyWith<$Res>? get groups;

}
/// @nodoc
class _$MountPanelCopyWithImpl<$Res>
    implements $MountPanelCopyWith<$Res> {
  _$MountPanelCopyWithImpl(this._self, this._then);

  final MountPanel _self;
  final $Res Function(MountPanel) _then;

/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? stored = freezed,Object? sources = null,Object? groups = freezed,}) {
  return _then(MountPanel(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as Profile,stored: freezed == stored ? _self.stored : stored // ignore: cast_nullable_to_non_nullable
as MountTargetState?,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<MountSourceItem>,groups: freezed == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as MountTarget?,
  ));
}
/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCopyWith<$Res> get target {
  
  return $ProfileCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountTargetStateCopyWith<$Res>? get stored {
    if (_self.stored == null) {
    return null;
  }

  return $MountTargetStateCopyWith<$Res>(_self.stored!, (value) {
    return _then(_self.copyWith(stored: value));
  });
}/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountTargetCopyWith<$Res>? get groups {
    if (_self.groups == null) {
    return null;
  }

  return $MountTargetCopyWith<$Res>(_self.groups!, (value) {
    return _then(_self.copyWith(groups: value));
  });
}
}


/// Adds pattern-matching-related methods to [MountPanel].
extension MountPanelPatterns on MountPanel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountPanel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountPanel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountPanel value)  $default,){
final _that = this;
switch (_that) {
case _MountPanel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountPanel value)?  $default,){
final _that = this;
switch (_that) {
case _MountPanel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Profile target,  MountTargetState? stored,  List<MountSourceItem> sources,  MountTarget? groups)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountPanel() when $default != null:
return $default(_that.target,_that.stored,_that.sources,_that.groups);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Profile target,  MountTargetState? stored,  List<MountSourceItem> sources,  MountTarget? groups)  $default,) {final _that = this;
switch (_that) {
case _MountPanel():
return $default(_that.target,_that.stored,_that.sources,_that.groups);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Profile target,  MountTargetState? stored,  List<MountSourceItem> sources,  MountTarget? groups)?  $default,) {final _that = this;
switch (_that) {
case _MountPanel() when $default != null:
return $default(_that.target,_that.stored,_that.sources,_that.groups);case _:
  return null;

}
}

}

/// @nodoc


class _MountPanel implements MountPanel {
  const _MountPanel({required this.target, this.stored,  List<MountSourceItem> sources = const [], this.groups}): _sources = sources;
  

@override final  Profile target;
@override final  MountTargetState? stored;
 final  List<MountSourceItem> _sources;
@override@JsonKey() List<MountSourceItem> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}

@override final  MountTarget? groups;

/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountPanelCopyWith<_MountPanel> get copyWith => __$MountPanelCopyWithImpl<_MountPanel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountPanel&&(identical(other.target, target) || other.target == target)&&(identical(other.stored, stored) || other.stored == stored)&&const DeepCollectionEquality().equals(other.sources, _sources)&&(identical(other.groups, groups) || other.groups == groups));
}


@override
int get hashCode {
    return Object.hash(runtimeType,target,stored,const DeepCollectionEquality().hash(_sources),groups);
}

@override
String toString() {
    return 'MountPanel(target: $target, stored: $stored, sources: $sources, groups: $groups)';
}


}

/// @nodoc
abstract mixin class _$MountPanelCopyWith<$Res> implements $MountPanelCopyWith<$Res> {
  factory _$MountPanelCopyWith(_MountPanel value, $Res Function(_MountPanel) _then) = __$MountPanelCopyWithImpl;
@override @useResult
$Res call({
 Profile target, MountTargetState? stored, List<MountSourceItem> sources, MountTarget? groups
});


@override $ProfileCopyWith<$Res> get target;@override $MountTargetStateCopyWith<$Res>? get stored;@override $MountTargetCopyWith<$Res>? get groups;

}
/// @nodoc
class __$MountPanelCopyWithImpl<$Res>
    implements _$MountPanelCopyWith<$Res> {
  __$MountPanelCopyWithImpl(this._self, this._then);

  final _MountPanel _self;
  final $Res Function(_MountPanel) _then;

/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? stored = freezed,Object? sources = null,Object? groups = freezed,}) {
  return _then(_MountPanel(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as Profile,stored: freezed == stored ? _self.stored : stored // ignore: cast_nullable_to_non_nullable
as MountTargetState?,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<MountSourceItem>,groups: freezed == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as MountTarget?,
  ));
}

/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCopyWith<$Res> get target {
  
  return $ProfileCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountTargetStateCopyWith<$Res>? get stored {
    if (_self.stored == null) {
    return null;
  }

  return $MountTargetStateCopyWith<$Res>(_self.stored!, (value) {
    return _then(_self.copyWith(stored: value));
  });
}/// Create a copy of MountPanel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountTargetCopyWith<$Res>? get groups {
    if (_self.groups == null) {
    return null;
  }

  return $MountTargetCopyWith<$Res>(_self.groups!, (value) {
    return _then(_self.copyWith(groups: value));
  });
}
}

/// @nodoc
mixin _$MountSaveResult {

 MountSaveOutcome get outcome; String? get message; MountTargetState? get state; List<String> get lostSelections;
/// Create a copy of MountSaveResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountSaveResultCopyWith<MountSaveResult> get copyWith => _$MountSaveResultCopyWithImpl<MountSaveResult>(this as MountSaveResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MountSaveResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountSaveResult&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.state, _this.state) || other.state == _this.state)&&const DeepCollectionEquality().equals(other.lostSelections, _this.lostSelections));
}


@override
int get hashCode {
  final _this = this as MountSaveResult;
  return Object.hash(runtimeType,_this.outcome,_this.message,_this.state,const DeepCollectionEquality().hash(_this.lostSelections));
}

@override
String toString() {
  final _this = this as MountSaveResult;
  return 'MountSaveResult(outcome: ${_this.outcome}, message: ${_this.message}, state: ${_this.state}, lostSelections: ${_this.lostSelections})';
}


}

/// @nodoc
abstract mixin class $MountSaveResultCopyWith<$Res>  {
  factory $MountSaveResultCopyWith(MountSaveResult value, $Res Function(MountSaveResult) _then) = _$MountSaveResultCopyWithImpl;
@useResult
$Res call({
 MountSaveOutcome outcome, String? message, MountTargetState? state, List<String> lostSelections
});


$MountTargetStateCopyWith<$Res>? get state;

}
/// @nodoc
class _$MountSaveResultCopyWithImpl<$Res>
    implements $MountSaveResultCopyWith<$Res> {
  _$MountSaveResultCopyWithImpl(this._self, this._then);

  final MountSaveResult _self;
  final $Res Function(MountSaveResult) _then;

/// Create a copy of MountSaveResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? outcome = null,Object? message = freezed,Object? state = freezed,Object? lostSelections = null,}) {
  return _then(MountSaveResult(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as MountSaveOutcome,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as MountTargetState?,lostSelections: null == lostSelections ? _self.lostSelections : lostSelections // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of MountSaveResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountTargetStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $MountTargetStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}


/// Adds pattern-matching-related methods to [MountSaveResult].
extension MountSaveResultPatterns on MountSaveResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountSaveResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountSaveResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountSaveResult value)  $default,){
final _that = this;
switch (_that) {
case _MountSaveResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountSaveResult value)?  $default,){
final _that = this;
switch (_that) {
case _MountSaveResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MountSaveOutcome outcome,  String? message,  MountTargetState? state,  List<String> lostSelections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountSaveResult() when $default != null:
return $default(_that.outcome,_that.message,_that.state,_that.lostSelections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MountSaveOutcome outcome,  String? message,  MountTargetState? state,  List<String> lostSelections)  $default,) {final _that = this;
switch (_that) {
case _MountSaveResult():
return $default(_that.outcome,_that.message,_that.state,_that.lostSelections);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MountSaveOutcome outcome,  String? message,  MountTargetState? state,  List<String> lostSelections)?  $default,) {final _that = this;
switch (_that) {
case _MountSaveResult() when $default != null:
return $default(_that.outcome,_that.message,_that.state,_that.lostSelections);case _:
  return null;

}
}

}

/// @nodoc


class _MountSaveResult implements MountSaveResult {
  const _MountSaveResult({required this.outcome, this.message, this.state,  List<String> lostSelections = const []}): _lostSelections = lostSelections;
  

@override final  MountSaveOutcome outcome;
@override final  String? message;
@override final  MountTargetState? state;
 final  List<String> _lostSelections;
@override@JsonKey() List<String> get lostSelections {
  if (_lostSelections is EqualUnmodifiableListView) return _lostSelections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lostSelections);
}


/// Create a copy of MountSaveResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountSaveResultCopyWith<_MountSaveResult> get copyWith => __$MountSaveResultCopyWithImpl<_MountSaveResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountSaveResult&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.message, message) || other.message == message)&&(identical(other.state, state) || other.state == state)&&const DeepCollectionEquality().equals(other.lostSelections, _lostSelections));
}


@override
int get hashCode {
    return Object.hash(runtimeType,outcome,message,state,const DeepCollectionEquality().hash(_lostSelections));
}

@override
String toString() {
    return 'MountSaveResult(outcome: $outcome, message: $message, state: $state, lostSelections: $lostSelections)';
}


}

/// @nodoc
abstract mixin class _$MountSaveResultCopyWith<$Res> implements $MountSaveResultCopyWith<$Res> {
  factory _$MountSaveResultCopyWith(_MountSaveResult value, $Res Function(_MountSaveResult) _then) = __$MountSaveResultCopyWithImpl;
@override @useResult
$Res call({
 MountSaveOutcome outcome, String? message, MountTargetState? state, List<String> lostSelections
});


@override $MountTargetStateCopyWith<$Res>? get state;

}
/// @nodoc
class __$MountSaveResultCopyWithImpl<$Res>
    implements _$MountSaveResultCopyWith<$Res> {
  __$MountSaveResultCopyWithImpl(this._self, this._then);

  final _MountSaveResult _self;
  final $Res Function(_MountSaveResult) _then;

/// Create a copy of MountSaveResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? outcome = null,Object? message = freezed,Object? state = freezed,Object? lostSelections = null,}) {
  return _then(_MountSaveResult(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as MountSaveOutcome,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as MountTargetState?,lostSelections: null == lostSelections ? _self._lostSelections : lostSelections // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of MountSaveResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountTargetStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $MountTargetStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}

/// @nodoc
mixin _$MountSourceRefresh {

 bool get updated; MountSourceItem? get item; String? get message; MountSaveOutcome? get application; List<String> get lostSelections;
/// Create a copy of MountSourceRefresh
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountSourceRefreshCopyWith<MountSourceRefresh> get copyWith => _$MountSourceRefreshCopyWithImpl<MountSourceRefresh>(this as MountSourceRefresh, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MountSourceRefresh;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountSourceRefresh&&(identical(other.updated, _this.updated) || other.updated == _this.updated)&&(identical(other.item, _this.item) || other.item == _this.item)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.application, _this.application) || other.application == _this.application)&&const DeepCollectionEquality().equals(other.lostSelections, _this.lostSelections));
}


@override
int get hashCode {
  final _this = this as MountSourceRefresh;
  return Object.hash(runtimeType,_this.updated,_this.item,_this.message,_this.application,const DeepCollectionEquality().hash(_this.lostSelections));
}

@override
String toString() {
  final _this = this as MountSourceRefresh;
  return 'MountSourceRefresh(updated: ${_this.updated}, item: ${_this.item}, message: ${_this.message}, application: ${_this.application}, lostSelections: ${_this.lostSelections})';
}


}

/// @nodoc
abstract mixin class $MountSourceRefreshCopyWith<$Res>  {
  factory $MountSourceRefreshCopyWith(MountSourceRefresh value, $Res Function(MountSourceRefresh) _then) = _$MountSourceRefreshCopyWithImpl;
@useResult
$Res call({
 bool updated, MountSourceItem? item, String? message, MountSaveOutcome? application, List<String> lostSelections
});


$MountSourceItemCopyWith<$Res>? get item;

}
/// @nodoc
class _$MountSourceRefreshCopyWithImpl<$Res>
    implements $MountSourceRefreshCopyWith<$Res> {
  _$MountSourceRefreshCopyWithImpl(this._self, this._then);

  final MountSourceRefresh _self;
  final $Res Function(MountSourceRefresh) _then;

/// Create a copy of MountSourceRefresh
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? updated = null,Object? item = freezed,Object? message = freezed,Object? application = freezed,Object? lostSelections = null,}) {
  return _then(MountSourceRefresh(
updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as bool,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as MountSourceItem?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,application: freezed == application ? _self.application : application // ignore: cast_nullable_to_non_nullable
as MountSaveOutcome?,lostSelections: null == lostSelections ? _self.lostSelections : lostSelections // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of MountSourceRefresh
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountSourceItemCopyWith<$Res>? get item {
    if (_self.item == null) {
    return null;
  }

  return $MountSourceItemCopyWith<$Res>(_self.item!, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// Adds pattern-matching-related methods to [MountSourceRefresh].
extension MountSourceRefreshPatterns on MountSourceRefresh {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountSourceRefresh value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountSourceRefresh() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountSourceRefresh value)  $default,){
final _that = this;
switch (_that) {
case _MountSourceRefresh():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountSourceRefresh value)?  $default,){
final _that = this;
switch (_that) {
case _MountSourceRefresh() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool updated,  MountSourceItem? item,  String? message,  MountSaveOutcome? application,  List<String> lostSelections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountSourceRefresh() when $default != null:
return $default(_that.updated,_that.item,_that.message,_that.application,_that.lostSelections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool updated,  MountSourceItem? item,  String? message,  MountSaveOutcome? application,  List<String> lostSelections)  $default,) {final _that = this;
switch (_that) {
case _MountSourceRefresh():
return $default(_that.updated,_that.item,_that.message,_that.application,_that.lostSelections);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool updated,  MountSourceItem? item,  String? message,  MountSaveOutcome? application,  List<String> lostSelections)?  $default,) {final _that = this;
switch (_that) {
case _MountSourceRefresh() when $default != null:
return $default(_that.updated,_that.item,_that.message,_that.application,_that.lostSelections);case _:
  return null;

}
}

}

/// @nodoc


class _MountSourceRefresh implements MountSourceRefresh {
  const _MountSourceRefresh({required this.updated, this.item, this.message, this.application,  List<String> lostSelections = const []}): _lostSelections = lostSelections;
  

@override final  bool updated;
@override final  MountSourceItem? item;
@override final  String? message;
@override final  MountSaveOutcome? application;
 final  List<String> _lostSelections;
@override@JsonKey() List<String> get lostSelections {
  if (_lostSelections is EqualUnmodifiableListView) return _lostSelections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lostSelections);
}


/// Create a copy of MountSourceRefresh
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountSourceRefreshCopyWith<_MountSourceRefresh> get copyWith => __$MountSourceRefreshCopyWithImpl<_MountSourceRefresh>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountSourceRefresh&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.item, item) || other.item == item)&&(identical(other.message, message) || other.message == message)&&(identical(other.application, application) || other.application == application)&&const DeepCollectionEquality().equals(other.lostSelections, _lostSelections));
}


@override
int get hashCode {
    return Object.hash(runtimeType,updated,item,message,application,const DeepCollectionEquality().hash(_lostSelections));
}

@override
String toString() {
    return 'MountSourceRefresh(updated: $updated, item: $item, message: $message, application: $application, lostSelections: $lostSelections)';
}


}

/// @nodoc
abstract mixin class _$MountSourceRefreshCopyWith<$Res> implements $MountSourceRefreshCopyWith<$Res> {
  factory _$MountSourceRefreshCopyWith(_MountSourceRefresh value, $Res Function(_MountSourceRefresh) _then) = __$MountSourceRefreshCopyWithImpl;
@override @useResult
$Res call({
 bool updated, MountSourceItem? item, String? message, MountSaveOutcome? application, List<String> lostSelections
});


@override $MountSourceItemCopyWith<$Res>? get item;

}
/// @nodoc
class __$MountSourceRefreshCopyWithImpl<$Res>
    implements _$MountSourceRefreshCopyWith<$Res> {
  __$MountSourceRefreshCopyWithImpl(this._self, this._then);

  final _MountSourceRefresh _self;
  final $Res Function(_MountSourceRefresh) _then;

/// Create a copy of MountSourceRefresh
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? updated = null,Object? item = freezed,Object? message = freezed,Object? application = freezed,Object? lostSelections = null,}) {
  return _then(_MountSourceRefresh(
updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as bool,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as MountSourceItem?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,application: freezed == application ? _self.application : application // ignore: cast_nullable_to_non_nullable
as MountSaveOutcome?,lostSelections: null == lostSelections ? _self._lostSelections : lostSelections // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of MountSourceRefresh
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountSourceItemCopyWith<$Res>? get item {
    if (_self.item == null) {
    return null;
  }

  return $MountSourceItemCopyWith<$Res>(_self.item!, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}

/// @nodoc
mixin _$MountCardSummary {

 int get mounted; int get failed;
/// Create a copy of MountCardSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MountCardSummaryCopyWith<MountCardSummary> get copyWith => _$MountCardSummaryCopyWithImpl<MountCardSummary>(this as MountCardSummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MountCardSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MountCardSummary&&(identical(other.mounted, _this.mounted) || other.mounted == _this.mounted)&&(identical(other.failed, _this.failed) || other.failed == _this.failed));
}


@override
int get hashCode {
  final _this = this as MountCardSummary;
  return Object.hash(runtimeType,_this.mounted,_this.failed);
}

@override
String toString() {
  final _this = this as MountCardSummary;
  return 'MountCardSummary(mounted: ${_this.mounted}, failed: ${_this.failed})';
}


}

/// @nodoc
abstract mixin class $MountCardSummaryCopyWith<$Res>  {
  factory $MountCardSummaryCopyWith(MountCardSummary value, $Res Function(MountCardSummary) _then) = _$MountCardSummaryCopyWithImpl;
@useResult
$Res call({
 int mounted, int failed
});




}
/// @nodoc
class _$MountCardSummaryCopyWithImpl<$Res>
    implements $MountCardSummaryCopyWith<$Res> {
  _$MountCardSummaryCopyWithImpl(this._self, this._then);

  final MountCardSummary _self;
  final $Res Function(MountCardSummary) _then;

/// Create a copy of MountCardSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mounted = null,Object? failed = null,}) {
  return _then(MountCardSummary(
mounted: null == mounted ? _self.mounted : mounted // ignore: cast_nullable_to_non_nullable
as int,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MountCardSummary].
extension MountCardSummaryPatterns on MountCardSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MountCardSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MountCardSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MountCardSummary value)  $default,){
final _that = this;
switch (_that) {
case _MountCardSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MountCardSummary value)?  $default,){
final _that = this;
switch (_that) {
case _MountCardSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int mounted,  int failed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MountCardSummary() when $default != null:
return $default(_that.mounted,_that.failed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int mounted,  int failed)  $default,) {final _that = this;
switch (_that) {
case _MountCardSummary():
return $default(_that.mounted,_that.failed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int mounted,  int failed)?  $default,) {final _that = this;
switch (_that) {
case _MountCardSummary() when $default != null:
return $default(_that.mounted,_that.failed);case _:
  return null;

}
}

}

/// @nodoc


class _MountCardSummary implements MountCardSummary {
  const _MountCardSummary({required this.mounted, required this.failed});
  

@override final  int mounted;
@override final  int failed;

/// Create a copy of MountCardSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MountCardSummaryCopyWith<_MountCardSummary> get copyWith => __$MountCardSummaryCopyWithImpl<_MountCardSummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MountCardSummary&&(identical(other.mounted, mounted) || other.mounted == mounted)&&(identical(other.failed, failed) || other.failed == failed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mounted,failed);
}

@override
String toString() {
    return 'MountCardSummary(mounted: $mounted, failed: $failed)';
}


}

/// @nodoc
abstract mixin class _$MountCardSummaryCopyWith<$Res> implements $MountCardSummaryCopyWith<$Res> {
  factory _$MountCardSummaryCopyWith(_MountCardSummary value, $Res Function(_MountCardSummary) _then) = __$MountCardSummaryCopyWithImpl;
@override @useResult
$Res call({
 int mounted, int failed
});




}
/// @nodoc
class __$MountCardSummaryCopyWithImpl<$Res>
    implements _$MountCardSummaryCopyWith<$Res> {
  __$MountCardSummaryCopyWithImpl(this._self, this._then);

  final _MountCardSummary _self;
  final $Res Function(_MountCardSummary) _then;

/// Create a copy of MountCardSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mounted = null,Object? failed = null,}) {
  return _then(_MountCardSummary(
mounted: null == mounted ? _self.mounted : mounted // ignore: cast_nullable_to_non_nullable
as int,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
