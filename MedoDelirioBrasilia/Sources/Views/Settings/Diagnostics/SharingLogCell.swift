import SwiftUI

struct SharingLogCell: View {

    let destination: ShareDestination
    let contentType: ContentType
    let contentTitle: String
    let dateTime: String
    let sentToServer: Bool
    
    var symbolColor: Color {
        switch destination {
        case .whatsApp:
            return .green
        case .telegram:
            return .blue
        case .other:
            return .primary
        }
    }
    var typeToText: String {
        switch contentType {
        case .sound:
            return "Som"
        case .song:
            return "Música"
        case .videoFromSound:
            return "Vídeo de Som"
        case .videoFromSong:
            return "Vídeo de Música"
        }
    }
    var adjective: String {
        switch contentType {
        case .sound:
            return "compartilhado"
        case .song:
            return "compartilhada"
        case .videoFromSound:
            return "compartilhado"
        case .videoFromSong:
            return "compartilhado"
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            Image(systemName: "arrow.up.right")
                .resizable()
                .scaledToFit()
                .frame(height: 16)
                .foregroundColor(symbolColor)
                .padding(.leading, 5)
            
            VStack(alignment: .leading, spacing: 5) {
                Text("\(typeToText) \"\(contentTitle)\" \(adjective)")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Text(dateTime)
                    .foregroundColor(.gray)
                    .font(.footnote)
            }
            
            Spacer()
            
            Image(systemName: sentToServer ? "circle.fill" : "circle.dashed")
                .resizable()
                .scaledToFit()
                .frame(height: 10)
                .foregroundColor(sentToServer ? .green : .primary)
                .padding(.trailing, 5)
        }
    }

}

struct SharingLogCell_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            SharingLogCell(destination: .whatsApp, contentType: .sound, contentTitle: "Adora falar rebuscado", dateTime: "11/06/2022 00:23", sentToServer: false)
            SharingLogCell(destination: .whatsApp, contentType: .sound, contentTitle: "Adora falar rebuscado", dateTime: "11/06/2022 00:23", sentToServer: true)
        }
        .previewLayout(.fixed(width: 375, height: 100))
    }

}
