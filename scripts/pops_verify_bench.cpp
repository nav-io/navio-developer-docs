#include <blsct/arith/elements.h>
#include <blsct/arith/mcl/mcl_init.h>
#include <blsct/pos/helpers.h>
#include <blsct/pos/proof.h>
#include <blsct/range_proof/generators.h>
#include <ctokens/tokenid.h>
#include <logging.h>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

using Clock = std::chrono::steady_clock;
using Ms = std::chrono::duration<double, std::milli>;
using Point = Mcl::Point;
using Scalar = Mcl::Scalar;
using Points = Elements<Point>;

BCLog::Logger& LogInstance()
{
    static BCLog::Logger logger;
    return logger;
}

bool fLogIPs = false;

void BCLog::Logger::LogPrintStr(
    const std::string&,
    const std::string&,
    const std::string&,
    int,
    BCLog::LogFlags,
    BCLog::Level)
{
}

bool BCLog::Logger::WillLogCategoryLevel(BCLog::LogFlags, BCLog::Level) const
{
    return false;
}

namespace {

struct BenchCase {
    size_t set_size;
    size_t iterations;
    double avg_ms;
    double median_ms;
    double min_ms;
    double max_ms;
};

struct PreparedProof {
    Points staked_commitments;
    Scalar eta_fiat_shamir;
    blsct::Message eta_phi;
    blsct::ProofOfStake proof;
    uint256 kernel_hash;
    unsigned int next_target;
};

PreparedProof PrepareProof(const size_t set_size)
{
    if (set_size < 2) {
        throw std::runtime_error("set_size must be at least 2");
    }

    range_proof::GeneratorsFactory<Mcl> gf;
    const auto gen = gf.GetInstance(TokenId());

    const Scalar stake_amount(1'000'000);
    const Scalar blinding = Scalar::Rand(true);
    const Point sigma = gen.G * stake_amount + gen.H * blinding;

    std::vector<Point> members;
    members.reserve(set_size);

    const size_t stake_index = set_size / 2;
    for (size_t i = 0; i < set_size; ++i) {
        if (i == stake_index) {
            members.push_back(sigma);
            continue;
        }

        Point candidate = gen.G * Scalar::Rand(true) + gen.H * Scalar::Rand(true);
        if (candidate == sigma) {
            candidate = candidate + gen.G;
        }
        members.push_back(candidate);
    }

    Points staked_commitments(members);

    const Scalar eta_fiat_shamir(42 + static_cast<uint64_t>(set_size));
    blsct::Message eta_phi(32);
    for (size_t i = 0; i < eta_phi.size(); ++i) {
        eta_phi[i] = static_cast<uint8_t>((set_size + i) & 0xff);
    }

    const uint32_t prev_time = 1'700'000'000u;
    const uint64_t stake_modifier = 0x0123456789abcdefULL;
    const uint32_t time = prev_time + 64u;
    const unsigned int next_target = 0x207fffffU;
    const bool hardened = true;

    blsct::ProofOfStake proof;
    try {
        proof = blsct::ProofOfStake(
            staked_commitments,
            eta_fiat_shamir,
            eta_phi,
            stake_amount,
            blinding,
            prev_time,
            stake_modifier,
            time,
            next_target,
            hardened
        );
    } catch (const std::exception& e) {
        throw std::runtime_error("proof construction failed for set_size=" + std::to_string(set_size) + ": " + e.what());
    }

    const uint256 kernel_hash = blsct::CalculateKernelHash(prev_time, stake_modifier, time, hardened);
    blsct::ProofOfStake::VerificationResult verify_res;
    try {
        verify_res = proof.Verify(staked_commitments, eta_fiat_shamir, eta_phi, kernel_hash, next_target);
    } catch (const std::exception& e) {
        throw std::runtime_error("proof self-check failed for set_size=" + std::to_string(set_size) + ": " + e.what());
    }
    if (verify_res != blsct::ProofOfStake::VALID) {
        throw std::runtime_error(
            "prepared proof did not verify: " + blsct::ProofOfStake::VerificationResultToString(verify_res)
        );
    }

    return PreparedProof{
        std::move(staked_commitments),
        eta_fiat_shamir,
        std::move(eta_phi),
        std::move(proof),
        kernel_hash,
        next_target,
    };
}

BenchCase RunCase(const size_t set_size, const double min_total_ms)
{
    auto prepared = PrepareProof(set_size);

    for (size_t i = 0; i < 2; ++i) {
        const auto res = prepared.proof.Verify(
            prepared.staked_commitments,
            prepared.eta_fiat_shamir,
            prepared.eta_phi,
            prepared.kernel_hash,
            prepared.next_target
        );
        if (res != blsct::ProofOfStake::VALID) {
            throw std::runtime_error("warmup verify failed");
        }
    }

    std::vector<double> samples_ms;
    samples_ms.reserve(128);

    const auto total_start = Clock::now();
    do {
        const auto start = Clock::now();
        const auto res = prepared.proof.Verify(
            prepared.staked_commitments,
            prepared.eta_fiat_shamir,
            prepared.eta_phi,
            prepared.kernel_hash,
            prepared.next_target
        );
        const auto end = Clock::now();

        if (res != blsct::ProofOfStake::VALID) {
            throw std::runtime_error("timed verify failed");
        }

        samples_ms.push_back(Ms(end - start).count());
    } while (samples_ms.size() < 3 || Ms(Clock::now() - total_start).count() < min_total_ms);

    auto sorted = samples_ms;
    std::sort(sorted.begin(), sorted.end());

    double total_ms = 0.0;
    for (double sample : samples_ms) {
        total_ms += sample;
    }

    return BenchCase{
        set_size,
        samples_ms.size(),
        total_ms / static_cast<double>(samples_ms.size()),
        sorted[sorted.size() / 2],
        sorted.front(),
        sorted.back(),
    };
}

} // namespace

int main(int argc, char** argv)
{
    volatile MclInit init;
    (void)init;

    std::vector<size_t> set_sizes;
    double min_total_ms = 1000.0;

    for (int i = 1; i < argc; ++i) {
        const std::string arg(argv[i]);
        if (arg.rfind("--min-total-ms=", 0) == 0) {
            min_total_ms = std::stod(arg.substr(std::string("--min-total-ms=").size()));
            continue;
        }
        set_sizes.push_back(static_cast<size_t>(std::stoull(arg)));
    }

    if (set_sizes.empty()) {
        set_sizes = {2, 4, 8, 16, 32, 64, 128, 256, 512, 1024};
    }

    std::cout << "set_size,iterations,avg_ms,median_ms,min_ms,max_ms\n";
    std::cout << std::fixed << std::setprecision(3);

    for (size_t set_size : set_sizes) {
        try {
            const BenchCase result = RunCase(set_size, min_total_ms);
            std::cout
                << result.set_size << ','
                << result.iterations << ','
                << result.avg_ms << ','
                << result.median_ms << ','
                << result.min_ms << ','
                << result.max_ms << '\n';
        } catch (const std::exception& e) {
            std::cerr << "bench failed for set_size=" << set_size << ": " << e.what() << '\n';
            return EXIT_FAILURE;
        }
    }

    return EXIT_SUCCESS;
}
