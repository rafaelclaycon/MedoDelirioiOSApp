//
//  ConfigCommandCollection.swift
//  MedoDelirioBrasilia
//
//  Created by Apple on 08/12/24.
//

import Foundation

/// `ConfigCommandCollection` is a group of related media commands.
struct ConfigCommandCollection {

    // The displayable name of the collection.

    let collectionName: String

    // The commands that belong to this collection.

    var commands: [ConfigCommand]

    init(_ collectionName: String, commands allCommands: [ConfigCommand],
         registered registeredCommands: [NowPlayableCommand],
         disabled disabledCommands: [NowPlayableCommand]) {

        self.collectionName = collectionName
        self.commands = allCommands

        // Flag commands in this collection as needing to be disabled or registered,
        // as requested.

        for (index, command) in commands.enumerated() {

            if registeredCommands.contains(command.command) {
                commands[index].shouldRegister = true
            }

            if disabledCommands.contains(command.command) {
                commands[index].shouldDisable = true
            }
        }
    }
}

/// `ConfigCommand` is the configuration to use for a specific media command.
struct ConfigCommand {

    // The command described by this configuration.

    let command: NowPlayableCommand

    // A displayable name for this configuration's command.

    let commandName: String

    // 'true' to register a handler for the corresponding MPRemoteCommandCenter command.

    var shouldRegister: Bool

    // 'true' to disable the corresponding MPRemoteCommandCenter command.

    var shouldDisable: Bool

    // Initialize a command configuration.

    init(_ command: NowPlayableCommand, _ commandName: String) {

        self.command = command
        self.commandName = commandName
        self.shouldDisable = false
        self.shouldRegister = false
    }
}
