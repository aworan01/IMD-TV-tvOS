import Foundation

struct PairingService {
    let endpoint: URL

    func createCode() async throws -> String {
        var request = URLRequest(url: endpoint.appendingPathComponent("pair"))
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 201,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = object["code"] as? String else { throw ImportError.invalidResponse }
        return code
    }

    func poll(code: String) async throws -> PairingPayload? {
        let url = endpoint.appendingPathComponent("pair").appendingPathComponent(code)
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        if status == 204 { return nil }
        guard status == 200 else { throw ImportError.invalidResponse }
        return try JSONDecoder().decode(PairingPayload.self, from: data)
    }
}

