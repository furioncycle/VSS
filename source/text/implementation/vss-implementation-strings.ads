--
--  Copyright (C) 2020-2024, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Ada_2022;

with System.Storage_Elements;

limited with VSS.Implementation.Text_Handlers;
with VSS.Unicode;

package VSS.Implementation.Strings is

   pragma Preelaborate;

   type Character_Offset is range -2 ** 30 .. 2 ** 30 - 1;
   subtype Character_Count is Character_Offset
     range 0 .. Character_Offset'Last;
   subtype Character_Index is Character_Count range 1 .. Character_Count'Last;

   type Grapheme_Count is range 0 .. 2 ** 30 - 1;
   subtype Grapheme_Index is Grapheme_Count range 1 .. Grapheme_Count'Last;

   No_Character : constant VSS.Unicode.Code_Point_Unit :=
     VSS.Unicode.Code_Point_Unit'Last;
   --  Special value to return when there is no character at given position.

   type Variable_Text_Handler_Access is
     access all VSS.Implementation.Text_Handlers.Abstract_String_Handler'Class;
   type Constant_Text_Handler_Access is
     access constant
       VSS.Implementation.Text_Handlers.Abstract_String_Handler'Class;

   ------------
   -- Cursor --
   ------------

   type Cursor is record
      UTF8_Offset  : VSS.Unicode.UTF8_Code_Unit_Offset  :=
        VSS.Unicode.UTF8_Code_Unit_Offset'Last;
      UTF16_Offset : VSS.Unicode.UTF16_Code_Unit_Offset :=
        VSS.Unicode.UTF16_Code_Unit_Offset'Last;
      Index        : Character_Count                    := 0;
   end record;
   --  Position of the character in the string. There are few special values,
   --  see table below.
   --
   --  UTF8_Offset and UTF16_Offset may be negative value, it means that
   --  actual offset is not know and can be computed by subtraction of this
   --  value from the total length of the data in corresponding encoding. It
   --  is used to avoid scanning of the whole string when cursor for the last
   --  character of the string is constructed.
   --
   --  Some special corner cases for values:
   --
   --                                   Index      UTF8_Offset   UTF16_Offset
   --   - invalid position                0           'Last         'Last
   --   - before first character          0             -1            -1
   --   - after last character        Length + 1     0 | Size      0 | Size
   --
   --  UTF8_Offset and UTF16_Offset components are put into the beginning to
   --  allow compiler to optimize operations on them with SIMD instructions.

   function Is_Invalid (Self : Cursor) return Boolean;
   --  Return True when cursor has special invalid value.

   -------------------
   -- Cursor_Offset --
   -------------------

   type Cursor_Offset is record
      UTF8_Offset  : VSS.Unicode.UTF8_Code_Unit_Offset  := 0;
      UTF16_Offset : VSS.Unicode.UTF16_Code_Unit_Offset := 0;
      Index_Offset : Character_Offset                   := 0;
   end record;
   --  Offset between positions of two Cursors. Also used as size of the
   --  segment.
   --
   --  Order of components is same with order of components of Cursor type.

   procedure Fixup_Insert
     (Self  : in out Cursor;
      Start : Cursor;
      Size  : Cursor_Offset);
   --  Fixup position of the cursor on insert operation at the given position
   --  and size.

   function Fixup_Delete
     (Self  : in out Cursor;
      Start : Cursor;
      Size  : Cursor_Offset) return Boolean;
   --  Fixup position of the cursor on delete operation at the given position
   --  and size. Return False and set position to invalid value when position
   --  of the cursor has been deleted.

   -----------------
   -- String_Data --
   -----------------

   --  String_Data is an raw storage for the associated text data.
   --  Storage contains an instance of the one of types derived from
   --  the Abstract_Text_Handler type.
   --
   --  Note: data layout is optimized for x86-64 CPU.
   --  Note: Storage has 8 bytes alignment.

   type String_Data is record
      Storage  : System.Storage_Elements.Storage_Array (0 .. 23) :=
        [others => 0];
      Capacity : Character_Count := 0;
   end record
     with Alignment   => 8,
          Object_Size => 256;
   for String_Data use record
      Storage  at 0  range  0 .. 191;
      Capacity at 24 range  0 ..  31;
   end record;

   overriding function "="
     (Left  : String_Data;
      Right : String_Data) return Boolean;
   --  Compare Left and Right string values.

   pragma Warnings (Off, "aggregate not fully initialized");
   Null_String_Data : constant String_Data := (others => <>);
   pragma Warnings (On, "aggregate not fully initialized");
   --  Data for "null" string. It is used around the code when null string
   --  need to be provided, to avoid compiler's warnings about uninitialized
   --  components. Some components are expected to be not initialized by
   --  default. Also, System.Null_Address is not static expression and can't be
   --  used here for initialization.

   function Variable_Handler
     (Data : in out String_Data) return not null Variable_Text_Handler_Access
        with Inline_Always;
   function Constant_Handler
     (Data : String_Data) return not null Constant_Text_Handler_Access
        with Inline_Always;
   --  Return string handler for given string data.
   --
   --  Call of Variable_Handler initializes string data when it is not
   --  initialized.

   procedure Reference (Data : in out String_Data) with Inline;
   --  Reference given string data. It is wrapper around Handler and call of
   --  its Reference subprogram when handler is not null.

   procedure Unreference (Data : in out String_Data) with Inline;
   --  Unreference given string data. It is wrapper around Handler and call of
   --  its Unreference subprogram when handler is not null. Data is set to
   --  "null" value before exit for safety.

end VSS.Implementation.Strings;
