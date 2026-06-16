"""
tests/test_infra_smoke.py

Run locally after `make infra-up`:  poetry run pytest tests/test_infra_smoke.py -v
"""

from __future__ import annotations

import os
import socket
import uuid
from pathlib import Path

import pytest

NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "please-change-me")
CHROMA_PERSIST_DIR = os.getenv("CHROMA_PERSIST_DIR", "./.chroma")


def _bolt_reachable(uri: str) -> bool:
    """Cheap TCP check so we skip (not fail) when Neo4j isn't up."""
    host_port = uri.split("://", 1)[-1]
    host, _, port = host_port.partition(":")
    try:
        with socket.create_connection((host, int(port or 7687)), timeout=2):
            return True
    except OSError:
        return False


# --------------------------------------------------------------------------- #
# Neo4j: write one node, read it back, clean up.
# --------------------------------------------------------------------------- #
@pytest.mark.skipif(
    not _bolt_reachable(NEO4J_URI),
    reason="Neo4j not reachable — run `make infra-up` first.",
)  # type: ignore[misc]
def test_neo4j_write_read_node() -> None:
    neo4j = pytest.importorskip("neo4j", reason="neo4j driver not installed")

    marker = f"smoke-{uuid.uuid4()}"
    driver = neo4j.GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
    try:
        with driver.session() as session:
            # write
            session.run("CREATE (:SmokeTest {marker: $marker})", marker=marker)
            # read back
            result = session.run(
                "MATCH (n:SmokeTest {marker: $marker}) RETURN n.marker AS m",
                marker=marker,
            )
            record = result.single()
            assert record is not None, "node was not written"
            assert record["m"] == marker
        # cleanup so the smoke node doesn't accumulate
        with driver.session() as session:
            session.run("MATCH (n:SmokeTest {marker: $marker}) DELETE n", marker=marker)
    finally:
        driver.close()


# --------------------------------------------------------------------------- #
# ChromaDB: add one embedding, query it back.
# --------------------------------------------------------------------------- #
def test_chroma_write_read_embedding(tmp_path: Path) -> None:
    chromadb = pytest.importorskip("chromadb", reason="chromadb not installed")

    # Use a temp dir so the test is hermetic and leaves no state behind.
    client = chromadb.PersistentClient(path=str(tmp_path / "chroma"))
    collection = client.get_or_create_collection(name="smoke")

    collection.add(
        ids=["doc-1"],
        embeddings=[[0.1, 0.2, 0.3, 0.4]],
        documents=["spinal cord stimulator coverage criterion"],
        metadatas=[{"source": "smoke"}],
    )

    result = collection.query(query_embeddings=[[0.1, 0.2, 0.3, 0.4]], n_results=1)
    assert result["ids"][0] == ["doc-1"]
    assert result["documents"][0][0].startswith("spinal cord stimulator")
