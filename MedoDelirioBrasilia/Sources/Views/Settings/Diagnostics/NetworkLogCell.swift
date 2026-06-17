import SwiftUI

struct NetworkLogCell: View {

    let callType: NetworkCallType
    let dateTime: String
    let wasSuccessful: Bool
    
    var typeToSymbol: String {
        switch callType {
        case .checkServerStatus:
            return "server.rack"
        case .postClientDeviceInfo:
            return "icloud.and.arrow.up"
        case .postShareCountStat:
            return "icloud.and.arrow.up"
        case .getSoundShareCountStats:
            return "icloud.and.arrow.down"
        }
    }
    
    var typeToText: String {
        switch callType {
        case .checkServerStatus:
            return "Verifica status do servidor"
        case .postClientDeviceInfo:
            return "Envia modelo do dispositivo"
        case .postShareCountStat:
            return "Envia estatísticas de compartilhamento dos sons"
        case .getSoundShareCountStats:
            return "Obtém estatísticas de compartilhamento dos sons"
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            Image(systemName: typeToSymbol)
                .resizable()
                .scaledToFit()
                .frame(height: 25)
                //.foregroundColor(symbolColor)
                .padding(.leading, 5)
            
            VStack(alignment: .leading, spacing: 5) {
                Text("\(typeToText)")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Text(dateTime)
                    .foregroundColor(.gray)
                    .font(.footnote)
            }
            
            Spacer()
            
            Image(systemName: "circle.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 10)
                .foregroundColor(wasSuccessful ? .green : .red)
                .padding(.trailing, 5)
        }
    }

}

struct NetworkLogCell_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            NetworkLogCell(callType: .checkServerStatus, dateTime: "14/06/2022 19:00:00", wasSuccessful: false)
            NetworkLogCell(callType: .checkServerStatus, dateTime: "14/06/2022 19:00:00", wasSuccessful: true)
        }
        .previewLayout(.fixed(width: 375, height: 100))
    }

}
