//
//  SimpleStorateStorageType.swift
//  SimpleStorage
//
//  Created by Dominik Gauggel on 30.10.20.
//

import Foundation

extension SimpleStorage {
    public func createStorageType(storageType: String) throws {
        let sql = "CREATE TABLE IF NOT EXISTS \(storageType) (id TEXT NOT NULL PRIMARY KEY)"

        try sqlite.performStatement(sql: sql)
        try addStorageTypeAttribute(storageType: storageType, attribute: Attribute(name: "created_at", type: .date, nullable: false))
        try addStorageTypeAttribute(storageType: storageType, attribute: Attribute(name: "updated_at", type: .date, nullable: false))
    }

    public func removeStorageType(storageType: String) throws {
        try sqlite.performStatement(sql: "DROP TABLE \(storageType)")
    }

    public func addStorageTypeAttribute(storageType: String, attribute: Attribute) throws {
        let null = attribute.nullable ? "NULL" : "NOT NULL"
        let attributeDescription: String
        switch attribute.type {
        case .uuid, .string:
            attributeDescription = createAttributeDescription(
                type: "TEXT",
                defaultValue: attribute.nullable ? "NULL" : "''",
                null: null
            )
        case .integer, .bool:
            attributeDescription = createAttributeDescription(
                type: "INTEGER",
                defaultValue: attribute.nullable ? "NULL" : "'0'",
                null: null
            )
        case .double, .date:
            attributeDescription = createAttributeDescription(
                type: "REAL",
                defaultValue: attribute.nullable ? "NULL" : "'0'",
                null: null
            )
        case .relationship(let referencedStorageType):
            if attribute.nullable {
                attributeDescription = "TEXT NULL REFERENCES \(referencedStorageType)(id) ON UPDATE SET NULL ON DELETE SET NULL DEFAULT NULL"
            } else {
                attributeDescription = "TEXT NOT NULL REFERENCES \(referencedStorageType)(id) ON UPDATE CASCADE ON DELETE CASCADE DEFAULT ''"
            }
        }

        let sql = "ALTER TABLE \(storageType) ADD COLUMN \(attribute.name) \(attributeDescription)"
        try sqlite.performStatement(sql: sql)
    }

    public func removeAttribute(storageType: String, attribute: String) throws {
        let columns = try self.tableDescription(storageType).columns.filter { $0.name != attribute }

        try sqlite.performStatement(sql: "PRAGMA foreign_keys = OFF")

        try sqlite.execute(sql: "BEGIN TRANSACTION")

        do {
            let temporaryStorageType = "temporary_storage_type_\(storageType)"
            try createStorageType(storageType: temporaryStorageType)
            for column in columns {
                if column.name == "id" || column.name == "created_at" || column.name == "updated_at" {
                    continue
                }
                var type: Attribute.AttributeType
                switch column.type {
                case .integer:
                    type = .integer
                case .text:
                    type = .string
                case .real:
                    type = .double
                }

                try addStorageTypeAttribute(
                    storageType: temporaryStorageType,
                    attribute: Attribute(name: column.name, type: type, nullable: column.nullable)
                )
            }

            let namesString = columns.map { $0.name }.joined(separator: ", ")
            try sqlite.performStatement(sql: "INSERT INTO \(temporaryStorageType)(\(namesString)) SELECT \(namesString) FROM \(storageType)")
            try sqlite.performStatement(sql: "DROP TABLE \(storageType)")
            try sqlite.performStatement(sql: "ALTER TABLE \(temporaryStorageType) RENAME TO \(storageType)")

            try sqlite.execute(sql: "COMMIT TRANSACTION")

            try sqlite.execute(sql: "PRAGMA foreign_keys = ON")
        } catch {
            let throwingDefer = {
                try self.sqlite.execute(sql: "PRAGMA foreign_keys = ON")
            }

            do {
                try sqlite.execute(sql: "ROLLBACK TRANSACTION")
            } catch {
                try throwingDefer()
                throw error
            }

            try throwingDefer()
            throw error
        }
    }

    func createAttributeDescription(type: String, defaultValue: String, null: String) -> String {
        return "\(type) \(null) DEFAULT \(defaultValue)"
    }

    func findStorageTypeVersion(storageType: String) throws -> Item {
        let expression = Expression(constraints: [Constraint(attribute: "storage_type", value: storageType)])

        guard let item = try? find(storageType: "storage_type_versions", expression: expression).first else {
            return Item(id: UUID(), values: ["storage_type": storageType, "version": 0])
        }
        return item
    }

    public func storageTypeVersion(storageType: String) throws -> Int {
        let item = try findStorageTypeVersion(storageType: storageType)
        return try item.value(name: "version")
    }

    public func setStorageTypeVersion(storageType: String, version: Int) throws {
        var item = try findStorageTypeVersion(storageType: storageType)
        item.values["version"] = version

        try createOrUpdate(storageType: "storage_type_versions", item: item)
    }
}