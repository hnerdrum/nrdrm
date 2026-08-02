{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Spec.Widget
  ( widgetModel,
  )
where

import ORM.Codegen.IR

widgetModel :: Model
widgetModel =
  Model
    { modelName = "Widget",
      modelTable = "test_widget",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          column "created_at" (withDefault DefaultNow (timestamptz "createdAt")),
          updatedAt (column "updated_at" (withDefault DefaultNow (timestamptz "updatedAt"))),
          text "name",
          nullable (text "description")
        ],
      modelRelations = []
    }
