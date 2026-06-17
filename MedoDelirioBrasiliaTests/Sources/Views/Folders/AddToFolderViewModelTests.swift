//
//  AddToFolderViewModelTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Claycon Schmitt on 01/02/23.
//

import Testing
@testable import MedoDelirio

struct AddToFolderViewModelTests {

    @Test("When folder selected and sound not in folder, should add")
    func test_canBeAddedToFolder_whenSingleSoundAndNotInFolder_shouldReturnArrayWithSameSound() throws {
        let repository = FakeUserFolderRepository()
        let sut = AddToFolderViewModel(userFolderRepository: repository)

        var content = [AnyEquatableMedoContent]()
        content.append(AnyEquatableMedoContent(Sound(id: "123", title: "Deu errado")))

        let result = sut.onExistingFolderSelected(
            folder: UserFolder(symbol: "", name: "Yuke", backgroundColor: ""),
            selectedContent: content
        )

        #expect(result?.hadSuccess == true)
        #expect(result?.pluralization == .singular)
        #expect(repository.didCallInsert == true)
        #expect(repository.didCallUpdate == true)
        #expect(repository.contents.count == 1)
        #expect(repository.contents.first! == "123")
    }

    @Test("When folder selected and single sound already in folder, should display warning")
    func test_canBeAddedToFolder_whenSingleSoundAndIsInFolder_shouldReturnEmptyArray() throws {
        let repository = FakeUserFolderRepository()
        repository.contents.append("123")
        let sut = AddToFolderViewModel(userFolderRepository: repository)
        
        var content = [AnyEquatableMedoContent]()
        content.append(AnyEquatableMedoContent(Sound(id: "123", title: "Deu errado")))

        let result = sut.onExistingFolderSelected(
            folder: UserFolder(symbol: "", name: "Yuke", backgroundColor: ""),
            selectedContent: content
        )

        #expect(result == nil)
        #expect(repository.didCallInsert == false)
        #expect(repository.didCallUpdate == false)
        #expect(sut.showAlert == true)
        #expect(sut.alertTitle == "Já Adicionado")
        #expect(sut.alertType == .ok)
    }

    @Test("When folder selected and multiple sounds not already in folder, should add all")
    func test_canBeAddedToFolder_whenMultipleSoundsAndNoneAreInFolder_shouldReturnAllSoundsOnArray() throws {
        let repository = FakeUserFolderRepository()
        let sut = AddToFolderViewModel(userFolderRepository: repository)

        var content = [AnyEquatableMedoContent]()
        content.append(AnyEquatableMedoContent(Sound(id: "123", title: "Deu errado")))
        content.append(AnyEquatableMedoContent(Sound(id: "456", title: "Aí eu acho exagero")))
        content.append(AnyEquatableMedoContent(Sound(id: "789", title: "Senhores, selva")))
        content.append(AnyEquatableMedoContent(Sound(id: "101112", title: "Acabou o flashback")))

        let result = sut.onExistingFolderSelected(
            folder: UserFolder(symbol: "", name: "Yuke", backgroundColor: ""),
            selectedContent: content
        )

        #expect(result?.hadSuccess == true)
        #expect(result?.pluralization == .plural)
        #expect(repository.didCallInsert == true)
        #expect(repository.didCallUpdate == true)
        #expect(repository.contents.count == 4)
    }

    @Test("When folder selected and multiple sounds all already in folder, should display warning")
    func test_canBeAddedToFolder_whenMultipleSoundsAndAllAreInFolder_shouldReturnEmptyArray() throws {
        let repository = FakeUserFolderRepository()
        repository.contents.append("123")
        repository.contents.append("456")
        repository.contents.append("789")
        repository.contents.append("101112")
        let sut = AddToFolderViewModel(userFolderRepository: repository)

        var content = [AnyEquatableMedoContent]()
        content.append(AnyEquatableMedoContent(Sound(id: "123", title: "Deu errado")))
        content.append(AnyEquatableMedoContent(Sound(id: "456", title: "Aí eu acho exagero")))
        content.append(AnyEquatableMedoContent(Sound(id: "789", title: "Senhores, selva")))
        content.append(AnyEquatableMedoContent(Sound(id: "101112", title: "Acabou o flashback")))

        let result = sut.onExistingFolderSelected(
            folder: UserFolder(symbol: "", name: "Yuke", backgroundColor: ""),
            selectedContent: content
        )
        
        #expect(result == nil)
        #expect(repository.didCallInsert == false)
        #expect(repository.didCallUpdate == false)
        #expect(sut.showAlert == true)
        #expect(sut.alertTitle == "Já Adicionados")
        #expect(sut.alertType == .ok)
    }

    @Test("When folder selected and multiple sounds, some in and some not in the folder, should prompt user")
    func test_canBeAddedToFolder_whenMultipleSoundsAndSomeAreInFolder_shouldReturnArrayWithTheOnesThatAreNotOnTheFolder() throws {
        let repository = FakeUserFolderRepository()
        repository.contents.append("123")
        repository.contents.append("789")
        let sut = AddToFolderViewModel(userFolderRepository: repository)

        var content = [AnyEquatableMedoContent]()
        content.append(AnyEquatableMedoContent(Sound(id: "123", title: "Deu errado")))
        content.append(AnyEquatableMedoContent(Sound(id: "456", title: "Aí eu acho exagero")))
        content.append(AnyEquatableMedoContent(Sound(id: "789", title: "Senhores, selva")))
        content.append(AnyEquatableMedoContent(Sound(id: "101112", title: "Acabou o flashback")))

        let result = sut.onExistingFolderSelected(
            folder: UserFolder(symbol: "", name: "Yuke", backgroundColor: ""),
            selectedContent: content
        )

        #expect(result == nil)
        #expect(repository.didCallInsert == false)
        #expect(repository.didCallUpdate == false)
        #expect(sut.showAlert == true)
        #expect(sut.alertTitle == "2 Conteúdos Já Adicionados")
        #expect(sut.alertType == .addOnlyNonOverlapping)
    }
}
