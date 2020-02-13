//
//  Storage.swift
//  Storage
//
//  Created by Dominik Gauggel on 11/12/19.
//  Copyright © 2019 couchbits GmbH. All rights reserved.
//

import Foundation

public protocol StorageTypeCreateable {
    func createStorageType(storageType: StorageType) throws
    func storageTypeVersion(storageType: StorageType) throws -> Int
    func incrementStorageTypeVersion(storageType: StorageType) throws
    @discardableResult
    func addAttribute(storageType: StorageType, attribute: StorageType.Attribute, defaultValue: Any) throws -> StorageType
}

public protocol StorageStoreable {
    @discardableResult
    func save(storageType: StorageType, item: StorageItem) throws -> StorageItem
    @discardableResult
    func save(storageType: StorageType, items: [StorageItem]) throws -> [StorageItem]
}

public protocol StorageReadeable {
    func all(storageType: StorageType) throws -> [StorageItem]
    func object(storageType: StorageType, id: UUID) throws -> StorageItem
    func find(storageType: StorageType, by constraints: [StorageConstraint]) throws -> [StorageItem]
}

public protocol StorageDeleteable {
    func delete(storageType: StorageType, id: UUID) throws
    func delete(storageType: StorageType, ids: [UUID]) throws
    func delete(storageType: StorageType, by constraints: [StorageConstraint]) throws
}

public typealias Storage = StorageTypeCreateable & StorageStoreable & StorageReadeable & StorageDeleteable
