import type { CodegenTypes } from 'react-native';

// Codegen before RN 0.80 only recognises these as bare identifiers
// (`Float`, not `CodegenTypes.Float`) and the parser reads the spec file in
// isolation, so the spec must import them by name from a separate module.
// Re-aliasing the namespace here keeps `tsc` on the strict-api surface
// (see LESSONS_LEARNED #1 and #23).

export type Float = CodegenTypes.Float;
export type Int32 = CodegenTypes.Int32;
export type WithDefault<
  Type extends number | boolean | string | ReadonlyArray<string>,
  Value extends Type | string | undefined | null,
> = CodegenTypes.WithDefault<Type, Value>;
export type DirectEventHandler<T> = CodegenTypes.DirectEventHandler<T>;
